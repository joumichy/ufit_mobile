import Foundation
import Observation

@MainActor
@Observable
final class MarketplaceStore {
    var outfits: [Outfit]
    var savedOutfitIDs = Set<String>()
    var feedErrorMessage: String?
    var actionMessage: String?
    var creatorDashboard: UFitCreatorDashboardDTO?
    var creatorOutfits: [UFitCreatorOutfitDTO] = []
    var creatorCommissions: [UFitCreatorCommissionDTO] = []
    var brandDashboard: UFitBrandDashboardDTO?
    var brandOrders: [BrandOrder]

    @ObservationIgnored private let client: UFitAPIClient
    @ObservationIgnored private var hasLoadedFeed = false
    @ObservationIgnored private var detailedOutfits = [String: Outfit]()

    init(client: UFitAPIClient, fallbackOutfits: [Outfit] = SampleData.outfits) {
        self.client = client
        self.outfits = fallbackOutfits
        self.brandOrders = SampleData.orders
    }

    static func live() -> MarketplaceStore {
        MarketplaceStore(client: UFitAPIClient())
    }

    var isAuthenticated: Bool {
        client.configuration.bearerToken != nil
    }

    var brandProfileID: String? {
        client.configuration.brandProfileID
    }

    func loadFeedIfNeeded() async {
        guard !hasLoadedFeed else { return }
        hasLoadedFeed = true
        await refreshFeed()
    }

    func refreshFeed() async {
        do {
            let response = try await client.fetchOutfitFeed(limit: 20)
            let remoteOutfits = response.items.enumerated().map { index, item in
                item.toOutfit(fallbackIndex: index)
            }
            feedErrorMessage = nil
            if !remoteOutfits.isEmpty {
                outfits = remoteOutfits
            }
        } catch {
            feedErrorMessage = friendlyMessage(for: error)
        }
    }

    func detail(for outfit: Outfit) async -> Outfit {
        if let detailed = detailedOutfits[outfit.id] {
            return detailed
        }

        do {
            let dto = try await client.fetchOutfitDetail(id: outfit.id)
            let detailed = dto.toOutfit(fallback: outfit)
            detailedOutfits[outfit.id] = detailed
            if let index = outfits.firstIndex(where: { $0.id == outfit.id }) {
                outfits[index] = detailed
            }
            return detailed
        } catch {
            actionMessage = friendlyMessage(for: error)
            return outfit
        }
    }

    func toggleSaved(outfit: Outfit) async {
        let wasSaved = savedOutfitIDs.contains(outfit.id)
        if wasSaved {
            savedOutfitIDs.remove(outfit.id)
        } else {
            savedOutfitIDs.insert(outfit.id)
        }

        do {
            if wasSaved {
                _ = try await client.unsaveOutfit(id: outfit.id)
            } else {
                _ = try await client.saveOutfit(id: outfit.id)
            }
            actionMessage = wasSaved ? "Removed from saved outfits." : "Saved to your wardrobe."
        } catch {
            if wasSaved {
                savedOutfitIDs.insert(outfit.id)
            } else {
                savedOutfitIDs.remove(outfit.id)
            }
            actionMessage = friendlyMessage(for: error)
        }
    }

    func checkout(outfit: Outfit, shippingAddress: UFitShippingAddress) async throws -> URL {
        let detail = await detail(for: outfit)
        let shoppablePieces = detail.pieces.filter { $0.isShoppable && $0.productID != nil }
        guard !shoppablePieces.isEmpty else {
            throw UFitAPIError.requestFailed(statusCode: 422, message: "This outfit does not expose shoppable pieces yet.")
        }

        for piece in shoppablePieces {
            guard let productID = piece.productID else { continue }
            let publicProduct = try await client.fetchPublicProduct(id: productID)
            guard let variant = publicProduct.variants.first(where: { $0.stockQuantity > 0 }) else {
                throw UFitAPIError.requestFailed(statusCode: 409, message: "\(publicProduct.name) is currently out of stock.")
            }
            _ = try await client.addCartItem(
                UFitAddCartItemRequest(
                    productVariantId: variant.id,
                    quantity: 1,
                    sourceOutfitId: detail.id,
                    sourceCreatorId: detail.sourceCreatorId
                )
            )
        }

        let session = try await client.checkout(UFitCheckoutRequest(shippingAddress: shippingAddress, shippingAmount: 0))
        guard let url = URL(string: session.url) else {
            throw UFitAPIError.invalidURL
        }
        return url
    }

    func loadCreatorWorkspace() async {
        do {
            async let dashboard = client.fetchCreatorDashboard()
            async let outfits = client.fetchCreatorOutfits(limit: 20)
            async let commissions = client.fetchCreatorCommissions(limit: 20)
            creatorDashboard = try await dashboard
            creatorOutfits = try await outfits.items
            creatorCommissions = try await commissions.items
        } catch {
            actionMessage = friendlyMessage(for: error)
        }
    }

    func loadBrandWorkspace() async {
        guard let brandProfileID else {
            actionMessage = "Set UFIT_BRAND_PROFILE_ID to load the brand workspace."
            return
        }

        do {
            async let dashboard = client.fetchBrandDashboard(brandProfileID: brandProfileID)
            async let orders = client.fetchBrandOrders(brandProfileID: brandProfileID, limit: 8)
            brandDashboard = try await dashboard
            brandOrders = try await orders.items.map { $0.toBrandOrder() }
        } catch {
            actionMessage = friendlyMessage(for: error)
        }
    }

    private func friendlyMessage(for error: Error) -> String {
        if let localized = error as? LocalizedError, let message = localized.errorDescription {
            return message
        }
        return error.localizedDescription
    }
}

extension UFitOutfitCardDTO {
    func toOutfit(fallbackIndex: Int) -> Outfit {
        let fallbackImage = SampleData.outfits.indices.contains(fallbackIndex) ? SampleData.outfits[fallbackIndex].imageName : "unsplash-09"
        return Outfit(
            id: id,
            imageName: coverImageUrl.isEmpty ? fallbackImage : coverImageUrl,
            creator: "UFit Creator",
            creatorAvatar: "UF",
            price: UFitMoney.format(totalPriceMax, currency: currency),
            likes: 0,
            comments: 0,
            title: title,
            description: "A curated silhouette selected by UFit.",
            currency: currency,
            totalPrice: totalPriceMax,
            sourceCreatorId: nil,
            sourceOutfitId: id,
            products: [],
            pieces: []
        )
    }
}

extension UFitOutfitDetailDTO {
    func toOutfit(fallback: Outfit) -> Outfit {
        let sortedItems = items.sorted { $0.position < $1.position }
        let products = sortedItems.map { item in
            OutfitProduct(
                id: item.product?.id ?? item.id,
                systemImage: item.symbolName,
                name: item.label,
                productID: item.product?.id,
                brandID: item.product?.brandId
            )
        }
        let pieces = sortedItems.map { item in
            OutfitPiece(
                id: item.id,
                name: item.label,
                brand: item.product?.brandId ?? "Independent brand",
                price: item.product.map { UFitMoney.format($0.price, currency: $0.currency) } ?? "On request",
                sizes: ["One Size"],
                productID: item.product?.id,
                isRequired: item.isRequired,
                isShoppable: item.isShoppable
            )
        }

        return Outfit(
            id: id,
            imageName: coverImageUrl.isEmpty ? fallback.imageName : coverImageUrl,
            creator: fallback.creator,
            creatorAvatar: fallback.creatorAvatar,
            price: UFitMoney.format(totalPriceMax, currency: currency),
            likes: fallback.likes,
            comments: fallback.comments,
            title: title,
            description: description,
            currency: currency,
            totalPrice: totalPriceMax,
            sourceCreatorId: creatorId,
            sourceOutfitId: id,
            products: products,
            pieces: pieces
        )
    }
}

private extension UFitOutfitItemDTO {
    var symbolName: String {
        switch itemType {
        case "shoes": "shoeprints.fill"
        case "bag": "handbag"
        case "accessory": "sunglasses"
        case "outerwear": "jacket"
        case "bottom": "figure.walk"
        default: "tshirt"
        }
    }
}

extension UFitBrandOrderDTO {
    func toBrandOrder() -> BrandOrder {
        BrandOrder(
            id: orderNumber,
            customer: sourceCreatorId == nil ? "Direct order" : "Creator sale",
            items: 1,
            total: UFitMoney.format(totalAmount, currency: currency),
            status: OrderStatus(apiStatus: status),
            date: UFitDate.short(createdAt)
        )
    }
}

enum UFitMoney {
    static func format(_ amount: Int, currency: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: Double(amount) / 100.0)) ?? "\(currency) \(amount)"
    }
}

enum UFitDate {
    static func short(_ rawValue: String?) -> String {
        guard let rawValue else { return "Today" }
        return String(rawValue.prefix(10))
    }
}
