import Foundation
import Observation

@MainActor
@Observable
final class MarketplaceStore {
    var outfits: [Outfit]
    var visibleFeedOutfitID: String?
    var visibleSavedOutfitID: String?
    var feedPhotoIDs = [String: String]()
    var expandedFeedIDs = Set<String>()
    private(set) var savedStates = [String: UFitSavedOutfitState]()
    private var savedStateFailures = Set<String>()
    private(set) var savedOutfits: [Outfit] = []
    private(set) var isLoadingFeed = false
    private(set) var hasLoadedFeed = false
    private(set) var isLoadingMoreFeed = false
    private(set) var feedMoreError: String?
    private(set) var isLoadingSavedOutfits = false
    private(set) var hasLoadedSavedOutfits = false
    private(set) var savedErrorMessage: String?
    private(set) var isLoadingMoreSavedOutfits = false
    private(set) var savedMoreError: String?
    var feedErrorMessage: String?
    var actionMessage: String?

    @ObservationIgnored private let client: UFitAPIClient
    @ObservationIgnored private let session: UFitSessionStore?
    @ObservationIgnored private var accountGeneration = UUID()
    @ObservationIgnored private var detailedOutfits = [String: Outfit]()
    @ObservationIgnored private var nextFeedCursor: String?
    @ObservationIgnored private var consumedFeedCursors = Set<String>()
    @ObservationIgnored private var feedGeneration = UUID()
    @ObservationIgnored private var savedGeneration = UUID()
    @ObservationIgnored private var nextSavedCursor: String?
    @ObservationIgnored private var consumedSavedCursors = Set<String>()
    @ObservationIgnored private var savedReferenceIDs = Set<String>()
    @ObservationIgnored private var lastSavedReference: UFitSavedReferencesDTO.Item?
    @ObservationIgnored private var savedStateRevisions = [String: UUID]()
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
    var accountID: String? { session?.user?.id }
    var hasMoreSavedOutfits: Bool { nextSavedCursor != nil }
    var feedFeedback: String? { savedStateFailures.isEmpty ? actionMessage : SavedCopy.verificationFailed }
    func dismissFeedFeedback() {
        savedStateFailures = []; actionMessage = nil
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
            await loadSavedStates(ids: remoteOutfits.map(\.id), force: true)
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
            await loadSavedStates(ids: page.items.map(\.id))
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
        guard isAuthenticated, !isLoadingSavedOutfits else { return }
        savedGeneration = UUID()
        let request = accountGeneration, userID = accountID, pageRequest = savedGeneration, revisions = savedStateRevisions
        isLoadingSavedOutfits = true; isLoadingMoreSavedOutfits = false; savedErrorMessage = nil; savedMoreError = nil
        defer { if accountGeneration == request, savedGeneration == pageRequest { isLoadingSavedOutfits = false } }
        do {
            let page = try await client.fetchSavedOutfits()
            let resolved = try await resolveSavedOutfits(page.items, account: request, page: pageRequest)
            guard accountGeneration == request, accountID == userID, savedGeneration == pageRequest else { return }
            acceptSavedReferences(page.items, revisions: revisions)
            savedOutfits = resolved.filter { savedStates[$0.id] != .notSaved }
            if let visibleSavedOutfitID, !savedOutfits.contains(where: { $0.id == visibleSavedOutfitID }) { self.visibleSavedOutfitID = nil }
            savedReferenceIDs = Set(page.items.map(\.id)); lastSavedReference = page.items.last
            nextSavedCursor = page.nextCursor; consumedSavedCursors = []
            hasLoadedSavedOutfits = true
        } catch {
            if !Task.isCancelled, !(error is CancellationError), accountGeneration == request, accountID == userID, savedGeneration == pageRequest {
                savedErrorMessage = friendlyMessage(for: error)
            }
        }
    }

    func loadMoreSavedOutfits() async {
        guard isAuthenticated, !isLoadingSavedOutfits, !isLoadingMoreSavedOutfits, savedErrorMessage == nil, let cursor = nextSavedCursor else { return }
        let request = accountGeneration, userID = accountID, pageRequest = savedGeneration, revisions = savedStateRevisions
        isLoadingMoreSavedOutfits = true; savedMoreError = nil
        defer { if accountGeneration == request, savedGeneration == pageRequest { isLoadingMoreSavedOutfits = false } }
        do {
            let page = try await client.fetchSavedOutfits(cursor: cursor)
            guard accountGeneration == request, accountID == userID, savedGeneration == pageRequest else { return }
            guard !consumedSavedCursors.contains(cursor), savedReferenceIDs.isDisjoint(with: page.items.map(\.id)) else { throw UFitSavedOutfitContractError.page }
            if let previous = lastSavedReference, let first = page.items.first {
                guard first.savedAt < previous.savedAt || (first.savedAt == previous.savedAt && first.id < previous.id) else { throw UFitSavedOutfitContractError.page }
            }
            let resolved = try await resolveSavedOutfits(page.items, account: request, page: pageRequest)
            guard accountGeneration == request, accountID == userID, savedGeneration == pageRequest else { return }
            acceptSavedReferences(page.items, revisions: revisions)
            let present = Set(savedOutfits.map(\.id))
            savedOutfits.append(contentsOf: resolved.filter { !present.contains($0.id) && savedStates[$0.id] != .notSaved })
            savedReferenceIDs.formUnion(page.items.map(\.id)); lastSavedReference = page.items.last ?? lastSavedReference
            nextSavedCursor = page.nextCursor; consumedSavedCursors.insert(cursor)
        } catch {
            if !Task.isCancelled, !(error is CancellationError), accountGeneration == request, accountID == userID, savedGeneration == pageRequest {
                savedMoreError = SavedCopy.moreUnavailable
            }
        }
    }

    private func resolveSavedOutfits(_ references: [UFitSavedReferencesDTO.Item], account: UUID, page: UUID) async throws -> [Outfit] {
        var resolved: [Outfit] = []
        for reference in references {
            guard accountGeneration == account, savedGeneration == page else { throw CancellationError() }
            let detail = try await client.fetchOutfitDetail(id: reference.id)
            resolved.append(detail.toOutfit())
        }
        return resolved
    }

    private func acceptSavedReferences(_ references: [UFitSavedReferencesDTO.Item], revisions: [String: UUID]) {
        for reference in references where revisions[reference.id] == savedStateRevisions[reference.id] {
            let state = savedStates[reference.id] ?? .unknown
            if case .unconfirmed = state { continue }
            if !state.isBusy { savedStates[reference.id] = .saved; savedStateFailures.remove(reference.id) }
        }
    }

    func loadSavedStates(ids: [String], force: Bool = false) async {
        guard isAuthenticated else { return }
        let identities = Set(ids).sorted().filter { id in
            let state = savedStates[id] ?? .unknown
            return !state.isBusy && (force || state.confirmedValue == nil)
        }
        guard !identities.isEmpty else { return }
        let request = accountGeneration, userID = accountID, previous = savedStates
        var revisions = [String: UUID]()
        for id in identities {
            let revision = UUID(); revisions[id] = revision; savedStateRevisions[id] = revision; savedStates[id] = .checking
        }
        for start in stride(from: .zero, to: identities.count, by: UFitSavedOutfitsHTTP.maximumIdentities) {
            guard accountGeneration == request, accountID == userID else { return }
            let batch = Array(identities[start..<min(start + UFitSavedOutfitsHTTP.maximumIdentities, identities.count)])
            do {
                let results = try await client.fetchSavedOutfitStates(ids: batch)
                guard accountGeneration == request, accountID == userID else { return }
                for result in results where savedStateRevisions[result.id] == revisions[result.id] {
                    savedStates[result.id] = result.saved ? .saved : .notSaved
                    savedStateFailures.remove(result.id)
                    if !result.saved { savedOutfits.removeAll { $0.id == result.id } }
                    if case .unconfirmed(let target)? = previous[result.id] {
                        if result.saved, let outfit = outfits.first(where: { $0.id == result.id }), !savedOutfits.contains(where: { $0.id == result.id }) {
                            savedOutfits.insert(outfit, at: .zero)
                        }
                        actionMessage = result.saved == target ? (target ? SavedCopy.saved : SavedCopy.removed) : (target ? SavedCopy.notApplied : SavedCopy.stillSaved)
                    }
                }
            } catch {
                guard accountGeneration == request, accountID == userID else { return }
                for id in batch where savedStateRevisions[id] == revisions[id] {
                    savedStates[id] = previous[id] ?? .unknown
                    if !Task.isCancelled { savedStateFailures.insert(id) }
                }
            }
        }
    }

    func clearAccountData() {
        accountGeneration = UUID()
        savedOutfits = []
        visibleSavedOutfitID = nil
        savedStates = [:]; savedStateRevisions = [:]; savedStateFailures = []
        savedGeneration = UUID(); nextSavedCursor = nil; consumedSavedCursors = []; savedReferenceIDs = []; lastSavedReference = nil
        hasLoadedSavedOutfits = false
        isLoadingSavedOutfits = false
        savedErrorMessage = nil; isLoadingMoreSavedOutfits = false; savedMoreError = nil
        actionMessage = nil
    }

    func toggleSaved(outfit: Outfit) async {
        guard isAuthenticated else { return }
        let state = savedStates[outfit.id] ?? .unknown
        guard !state.isBusy else { return }
        actionMessage = nil
        guard let wasSaved = state.confirmedValue else { await loadSavedStates(ids: [outfit.id], force: true); return }
        let request = accountGeneration, userID = accountID, target = !wasSaved
        invalidateSavedPagination()
        savedStateRevisions[outfit.id] = UUID(); savedStates[outfit.id] = .updating(target)
        do {
            try await client.setSavedOutfit(id: outfit.id, saved: target)
            guard accountGeneration == request, accountID == userID else { return }
            invalidateSavedPagination()
            savedStates[outfit.id] = target ? .saved : .notSaved
            savedOutfits.removeAll { $0.id == outfit.id }
            if target { savedOutfits.insert(outfit, at: .zero) }
            actionMessage = target ? SavedCopy.saved : SavedCopy.removed
        } catch {
            guard accountGeneration == request, accountID == userID else { return }
            invalidateSavedPagination()
            savedStates[outfit.id] = .unconfirmed(target)
            await loadSavedStates(ids: [outfit.id], force: true)
        }
        if accountGeneration == request, accountID == userID, !hasLoadedSavedOutfits {
            await loadSavedOutfits()
        }
    }

    private func invalidateSavedPagination() {
        // A page read started before a write must not undo its visible result.
        savedGeneration = UUID(); isLoadingSavedOutfits = false; isLoadingMoreSavedOutfits = false
    }

    private enum SavedCopy {
        static let removed = String(localized: "Tenue retirée des favoris.")
        static let saved = String(localized: "Tenue enregistrée.")
        static let notApplied = String(localized: "La tenue n’a pas été enregistrée.")
        static let stillSaved = String(localized: "La tenue est toujours dans vos favoris.")
        static let verificationFailed = String(localized: "L’état des favoris n’a pas pu être vérifié. Touchez le marque-page pour vérifier à nouveau.")
        static let moreUnavailable = String(localized: "La suite des favoris est indisponible.")
    }

    private func friendlyMessage(for error: Error) -> String {
        if let localized = error as? LocalizedError, let message = localized.errorDescription {
            return message
        }
        return error.localizedDescription
    }
}

enum UFitOutfitPresentation {
    static let editorial = String(localized: "Sélection Ufit")
    static let initials = "UF"
    static let inspiration = String(localized: "Inspiration")
    static let unavailable = String(localized: "Article indisponible")
    private static let unavailablePrices = String(localized: "Pièces indisponibles à l’achat")
    static let empty = String()
    static func priceSummary(prices: [UFitProductPriceDTO], items: [UFitOutfitItemDTO]) -> String {
        if prices.isEmpty && items.contains(where: \.isShoppable) { return unavailablePrices }
        return UFitMoney.ranges(prices)
    }
    static func initials(for author: OutfitAuthor?) -> String {
        guard let author else { return initials }
        return author.name.split(whereSeparator: \.isWhitespace).prefix(2).compactMap(\.first).map(String.init).joined()
    }
}

extension UFitOutfitCardDTO {
    func toOutfit() -> Outfit {
        Outfit(id: id, imageName: coverImageUrl,
            creator: author?.name ?? UFitOutfitPresentation.editorial,
            creatorAvatar: UFitOutfitPresentation.initials(for: author), author: author,
            price: UFitOutfitPresentation.priceSummary(prices: prices, items: items), title: title, description: UFitOutfitPresentation.empty,
            sourceCreatorId: creatorId, sourceOutfitId: id,
            products: items.sorted { $0.position < $1.position }.map { .init(id: $0.id, itemType: $0.itemType, name: $0.label, productID: $0.product?.id, brandID: $0.product?.brandId, image: $0.product?.imageUrl, brandName: $0.product?.brandName,
                price: $0.product.map { UFitMoney.format($0.price, currency: $0.currency) } ?? ($0.isShoppable ? UFitOutfitPresentation.unavailable : UFitOutfitPresentation.inspiration)) },
            pieces: [], photos: images.sorted { $0.position < $1.position }, pins: pins)
    }
}

extension UFitOutfitDetailDTO {
    func toOutfit() -> Outfit {
        let sorted = items.sorted { $0.position < $1.position }
        let products = sorted.map { item in
            OutfitProduct(id: item.id, itemType: item.itemType, name: item.label,
                productID: item.product?.id, brandID: item.product?.brandId, image: item.product?.imageUrl, brandName: item.product?.brandName,
                price: item.product.map { UFitMoney.format($0.price, currency: $0.currency) } ?? (item.isShoppable ? UFitOutfitPresentation.unavailable : UFitOutfitPresentation.inspiration))
        }
        let pieces = sorted.map { item in
            OutfitPiece(id: item.id, name: item.label, brand: UFitOutfitPresentation.empty,
                price: item.product.map { UFitMoney.format($0.price, currency: $0.currency) } ?? (item.isShoppable ? UFitOutfitPresentation.unavailable : UFitOutfitPresentation.inspiration),
                sizes: [], productID: item.product?.id, isRequired: item.isRequired, isShoppable: item.isShoppable)
        }
        return Outfit(id: id, imageName: coverImageUrl,
            creator: author?.name ?? UFitOutfitPresentation.editorial,
            creatorAvatar: UFitOutfitPresentation.initials(for: author), author: author,
            price: UFitOutfitPresentation.priceSummary(prices: prices, items: items), title: title, description: description,
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
