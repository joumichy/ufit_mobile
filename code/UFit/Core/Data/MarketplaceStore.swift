import Foundation
import Observation

@MainActor
@Observable
final class MarketplaceStore {
    var outfits: [Outfit]
    var savedOutfitIDs = Set<String>()
    var savedOutfits: [Outfit] = []
    private(set) var savingOutfitIDs = Set<String>()
    private(set) var isLoadingFeed = false
    var feedErrorMessage: String?
    var actionMessage: String?
    var creatorDashboard: UFitCreatorDashboardDTO?
    var creatorOutfits: [UFitCreatorOutfitDTO] = []
    var creatorCommissions: [UFitCreatorCommissionDTO] = []
    var brandDashboard: UFitBrandDashboardDTO?
    var brandOrders: [BrandOrder]

    @ObservationIgnored private let client: UFitAPIClient
    @ObservationIgnored private let session: UFitSessionStore?
    @ObservationIgnored private var hasLoadedFeed = false
    @ObservationIgnored private var detailedOutfits = [String: Outfit]()

    init(client: UFitAPIClient, session: UFitSessionStore? = nil, fallbackOutfits: [Outfit] = []) {
        self.client = client
        self.session = session
        self.outfits = fallbackOutfits
        self.brandOrders = []
    }

    static func live(client: UFitAPIClient = UFitAPIClient(), session: UFitSessionStore? = nil) -> MarketplaceStore {
        MarketplaceStore(client: client, session: session)
    }

    var isAuthenticated: Bool {
        session?.user != nil || client.configuration.bearerToken != nil
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
        guard !isLoadingFeed else { return }
        isLoadingFeed = true
        defer { isLoadingFeed = false }
        do {
            let response = try await client.fetchOutfitFeed(limit: 20)
            let remoteOutfits = response.items.map { $0.toOutfit() }
            feedErrorMessage = nil
            outfits = remoteOutfits
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
            let detailed = dto.toOutfit()
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

    func loadSavedOutfits() async {
        do {
            let page = try await client.fetchSavedOutfits()
            var resolved: [Outfit] = []
            for reference in page.items {
                let detail = try await client.fetchOutfitDetail(id: reference.id)
                resolved.append(detail.toOutfit())
            }
            savedOutfits = resolved
            savedOutfitIDs = Set(savedOutfits.map(\.id))
        } catch { actionMessage = friendlyMessage(for: error) }
    }

    func clearAccountData() {
        savedOutfits = []
        savedOutfitIDs = []
        creatorDashboard = nil
        creatorOutfits = []
        creatorCommissions = []
        brandDashboard = nil
        brandOrders = []
        actionMessage = nil
    }

    func toggleSaved(outfit: Outfit) async {
        guard !savingOutfitIDs.contains(outfit.id) else { return }
        savingOutfitIDs.insert(outfit.id)
        defer { savingOutfitIDs.remove(outfit.id) }
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
            if wasSaved { savedOutfits.removeAll { $0.id == outfit.id } }
            else { savedOutfits.append(outfit) }
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

private enum OutfitPresentation {
    static let editorial = String(localized: "Sélection Ufit")
    static let initials = "UF"
    static let inspiration = String(localized: "Inspiration")
    static let empty = String()
    static func initials(for author: OutfitAuthor?) -> String {
        guard let author else { return initials }
        return author.name.split(whereSeparator: \.isWhitespace).prefix(2).compactMap(\.first).map(String.init).joined()
    }
}

extension UFitOutfitCardDTO {
    func toOutfit() -> Outfit {
        Outfit(id: id, imageName: coverImageUrl,
            creator: author?.name ?? OutfitPresentation.editorial,
            creatorAvatar: OutfitPresentation.initials(for: author),
            price: UFitMoney.ranges(prices), title: title, description: OutfitPresentation.empty,
            sourceCreatorId: creatorId, sourceOutfitId: id, products: [], pieces: [])
    }
}

extension UFitOutfitDetailDTO {
    func toOutfit() -> Outfit {
        let sorted = items.sorted { $0.position < $1.position }
        let products = sorted.map { item in
            OutfitProduct(id: item.id, systemImage: item.symbolName, name: item.label,
                productID: item.product?.id, brandID: item.product?.brandId)
        }
        let pieces = sorted.map { item in
            OutfitPiece(id: item.id, name: item.label, brand: OutfitPresentation.empty,
                price: item.product.map { UFitMoney.format($0.price, currency: $0.currency) } ?? OutfitPresentation.inspiration,
                sizes: [], productID: item.product?.id, isRequired: item.isRequired, isShoppable: item.isShoppable)
        }
        return Outfit(id: id, imageName: coverImageUrl,
            creator: author?.name ?? OutfitPresentation.editorial,
            creatorAvatar: OutfitPresentation.initials(for: author),
            price: UFitMoney.ranges(prices), title: title, description: description,
            sourceCreatorId: creatorId, sourceOutfitId: id, products: products, pieces: pieces)
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
    private static let locale = Locale(identifier: "fr_CH")
    private static let decimalBase = Decimal(10)
    private static let separator = " + "
    private static let rangeSeparator = " – "
    private static let inspiration = String(localized: "Pièces d’inspiration")
    static func format(_ amount: Int, currency: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = locale
        formatter.currencyCode = currency
        var divisor = Decimal(1)
        for _ in 0..<formatter.maximumFractionDigits { divisor *= decimalBase }
        let major = NSDecimalNumber(decimal: Decimal(amount) / divisor)
        return formatter.string(from: major) ?? major.stringValue + currency
    }
    static func ranges(_ prices: [UFitProductPriceDTO]) -> String {
        guard !prices.isEmpty else { return inspiration }
        return prices.map { range in
            let minimum = format(range.min, currency: range.currency)
            return range.min == range.max ? minimum : minimum + rangeSeparator + format(range.max, currency: range.currency)
        }.joined(separator: separator)
    }
}

enum UFitDate {
    static func short(_ rawValue: String?) -> String {
        guard let rawValue else { return "Today" }
        return String(rawValue.prefix(10))
    }
}
