import Foundation
import Observation

@MainActor
@Observable
final class MarketplaceStore {
    var outfits: [Outfit]
    var visibleFeedOutfitID: String?
    var feedPhotoIDs = [String: String]()
    var expandedFeedIDs = Set<String>()
    var savedOutfitIDs = Set<String>()
    var savedOutfits: [Outfit] = []
    private(set) var savingOutfitIDs = Set<String>()
    private(set) var isLoadingFeed = false
    private(set) var hasLoadedFeed = false
    private(set) var isLoadingMoreFeed = false
    private(set) var feedMoreError: String?
    private(set) var isLoadingSavedOutfits = false
    private(set) var hasLoadedSavedOutfits = false
    private(set) var savedErrorMessage: String?
    var feedErrorMessage: String?
    var actionMessage: String?

    @ObservationIgnored private let client: UFitAPIClient
    @ObservationIgnored private let session: UFitSessionStore?
    @ObservationIgnored private var accountGeneration = UUID()
    @ObservationIgnored private var detailedOutfits = [String: Outfit]()
    @ObservationIgnored private var nextFeedCursor: String?
    @ObservationIgnored private var consumedFeedCursors = Set<String>()
    @ObservationIgnored private var feedGeneration = UUID()
    private enum FeedPaging {
        static let prefetchDistance = 3
        static let unavailable = String(localized: "La suite des tenues n’a pas pu être chargée. Les tenues déjà affichées restent disponibles.")
    }

    init(client: UFitAPIClient, session: UFitSessionStore? = nil, fallbackOutfits: [Outfit] = []) {
        self.client = client
        self.session = session
        self.outfits = fallbackOutfits
    }

    static func live(client: UFitAPIClient = UFitAPIClient(), session: UFitSessionStore? = nil) -> MarketplaceStore {
        MarketplaceStore(client: client, session: session)
    }

    var isAuthenticated: Bool {
        session?.user != nil || client.configuration.bearerToken != nil
    }

    func loadFeedIfNeeded() async {
        guard !hasLoadedFeed else { return }
        await refreshFeed()
    }

    func refreshFeed() async {
        guard !isLoadingFeed else { return }
        feedGeneration = UUID(); let request = feedGeneration
        isLoadingFeed = true; isLoadingMoreFeed = false; feedErrorMessage = nil; feedMoreError = nil
        defer { if feedGeneration == request { isLoadingFeed = false } }
        do {
            let response = try await client.fetchOutfitFeed()
            guard feedGeneration == request else { return }
            let remoteOutfits = response.items.map { $0.toOutfit() }
            feedErrorMessage = nil
            outfits = remoteOutfits
            nextFeedCursor = response.nextCursor; consumedFeedCursors = []
            hasLoadedFeed = true
            if let visibleFeedOutfitID, !remoteOutfits.contains(where: { $0.id == visibleFeedOutfitID }) { self.visibleFeedOutfitID = nil }
        } catch is CancellationError {
        } catch {
            if feedGeneration == request { feedErrorMessage = friendlyMessage(for: error) }
        }
    }

    func loadMoreFeedIfNeeded(near id: String) async {
        guard feedMoreError == nil, let index = outfits.firstIndex(where: { $0.id == id }),
              index >= outfits.count - FeedPaging.prefetchDistance else { return }
        await loadMoreFeed()
    }

    func loadMoreFeed() async {
        guard !isLoadingFeed, !isLoadingMoreFeed, feedErrorMessage == nil, let cursor = nextFeedCursor else { return }
        let request = feedGeneration
        isLoadingMoreFeed = true; feedMoreError = nil
        defer { if feedGeneration == request { isLoadingMoreFeed = false } }
        do {
            let page = try await client.fetchOutfitFeed(cursor: cursor)
            guard feedGeneration == request else { return }
            guard !consumedFeedCursors.contains(cursor), Set(outfits.map(\.id)).isDisjoint(with: page.items.map(\.id)) else {
                throw UFitPublicProfileContractError.outfits
            }
            outfits.append(contentsOf: page.items.map { $0.toOutfit() })
            nextFeedCursor = page.nextCursor; consumedFeedCursors.insert(cursor)
        } catch is CancellationError {
        } catch {
            if feedGeneration == request { feedMoreError = FeedPaging.unavailable }
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
        guard !isLoadingSavedOutfits else { return }
        let request = accountGeneration, userID = session?.user?.id
        isLoadingSavedOutfits = true; savedErrorMessage = nil
        defer { if accountGeneration == request { isLoadingSavedOutfits = false } }
        do {
            let page = try await client.fetchSavedOutfits()
            guard accountGeneration == request, session?.user?.id == userID else { return }
            var resolved: [Outfit] = []
            for reference in page.items {
                guard accountGeneration == request, session?.user?.id == userID else { return }
                let detail = try await client.fetchOutfitDetail(id: reference.id)
                resolved.append(detail.toOutfit())
            }
            guard accountGeneration == request, session?.user?.id == userID else { return }
            savedOutfits = resolved
            savedOutfitIDs = Set(savedOutfits.map(\.id))
            hasLoadedSavedOutfits = true
        } catch {
            if accountGeneration == request, session?.user?.id == userID { savedErrorMessage = friendlyMessage(for: error) }
        }
    }

    func clearAccountData() {
        accountGeneration = UUID()
        savedOutfits = []
        savedOutfitIDs = []
        savingOutfitIDs = []
        hasLoadedSavedOutfits = false
        isLoadingSavedOutfits = false
        savedErrorMessage = nil
        actionMessage = nil
    }

    func toggleSaved(outfit: Outfit) async {
        guard !savingOutfitIDs.contains(outfit.id) else { return }
        let request = accountGeneration, userID = session?.user?.id
        savingOutfitIDs.insert(outfit.id)
        defer { if accountGeneration == request { savingOutfitIDs.remove(outfit.id) } }
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
            guard accountGeneration == request, session?.user?.id == userID else { return }
            if wasSaved { savedOutfits.removeAll { $0.id == outfit.id } }
            else { savedOutfits.append(outfit) }
            actionMessage = wasSaved ? SavedCopy.removed : SavedCopy.saved
        } catch {
            guard accountGeneration == request, session?.user?.id == userID else { return }
            if wasSaved {
                savedOutfitIDs.insert(outfit.id)
            } else {
                savedOutfitIDs.remove(outfit.id)
            }
            actionMessage = friendlyMessage(for: error)
        }
    }

    private enum SavedCopy {
        static let removed = String(localized: "Tenue retirée des favoris.")
        static let saved = String(localized: "Tenue enregistrée.")
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
    static let unavailable = String(localized: "Article indisponible")
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
            creatorAvatar: OutfitPresentation.initials(for: author), author: author,
            price: UFitMoney.ranges(prices), title: title, description: OutfitPresentation.empty,
            sourceCreatorId: creatorId, sourceOutfitId: id,
            products: items.sorted { $0.position < $1.position }.map { .init(id: $0.id, systemImage: $0.itemType.symbol, name: $0.label, productID: $0.product?.id, brandID: $0.product?.brandId, image: $0.product?.imageUrl, brandName: $0.product?.brandName,
                price: $0.product.map { UFitMoney.format($0.price, currency: $0.currency) } ?? ($0.isShoppable ? OutfitPresentation.unavailable : OutfitPresentation.inspiration)) },
            pieces: [], photos: images.sorted { $0.position < $1.position }, pins: pins)
    }
}

extension UFitOutfitDetailDTO {
    func toOutfit() -> Outfit {
        let sorted = items.sorted { $0.position < $1.position }
        let products = sorted.map { item in
            OutfitProduct(id: item.id, systemImage: item.itemType.symbol, name: item.label,
                productID: item.product?.id, brandID: item.product?.brandId, image: item.product?.imageUrl, brandName: item.product?.brandName,
                price: item.product.map { UFitMoney.format($0.price, currency: $0.currency) } ?? (item.isShoppable ? OutfitPresentation.unavailable : OutfitPresentation.inspiration))
        }
        let pieces = sorted.map { item in
            OutfitPiece(id: item.id, name: item.label, brand: OutfitPresentation.empty,
                price: item.product.map { UFitMoney.format($0.price, currency: $0.currency) } ?? OutfitPresentation.inspiration,
                sizes: [], productID: item.product?.id, isRequired: item.isRequired, isShoppable: item.isShoppable)
        }
        return Outfit(id: id, imageName: coverImageUrl,
            creator: author?.name ?? OutfitPresentation.editorial,
            creatorAvatar: OutfitPresentation.initials(for: author), author: author,
            price: UFitMoney.ranges(prices), title: title, description: description,
            sourceCreatorId: creatorId, sourceOutfitId: id, products: products, pieces: pieces, photos: images.sorted { $0.position < $1.position }, pins: pins)
    }
}

extension UFitMoney {
    private static let separator = " + "
    private static let rangeSeparator = " – "
    private static let inspiration = String(localized: "Pièces d’inspiration")
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
