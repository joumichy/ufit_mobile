import Foundation
import Observation

@MainActor @Observable
final class UFitManagedOutfitsStore {
    let scope: UFitOutfitScope?
    let title: String
    let subtitle: String?
    let access: UFitOutfitAccess
    var showingCalendar = false
    var calendarMonth = Date()
    var calendarSelectedDay = Date()
    private(set) var outfits: [UFitManagedOutfit] = []
    private(set) var selectedStatus: UFitOutfitStatus?
    private(set) var hasLoaded = false
    private(set) var isLoading = false
    private(set) var isLoadingMore = false
    private(set) var nextCursor: String?
    private(set) var busyIDs = Set<String>()
    private(set) var message: String?
    @ObservationIgnored private var generation = UUID()
    @ObservationIgnored private var openingID: String?
    @ObservationIgnored private var pageCursors = Set<String>()
    @ObservationIgnored let client: UFitAPIClient
    @ObservationIgnored let session: UFitSessionStore
    @ObservationIgnored private let userID: String?
    init(scope: UFitOutfitScope?, title: String, subtitle: String?, access: UFitOutfitAccess, client: UFitAPIClient, session: UFitSessionStore, initialStatus: UFitOutfitStatus? = nil) {
        self.scope = scope; self.title = title; self.subtitle = subtitle; self.access = access; self.client = client; self.session = session
        userID = session.user?.id; selectedStatus = access == .administrator ? .published : initialStatus
    }
    var rows: [UFitManagedOutfitRow] { outfits.map { $0.row() } }
    var isCurrentAccount: Bool { userID != nil && session.user?.id == userID }
    func cancelOpening() { openingID = nil }
    func filter(_ status: UFitOutfitStatus?) async {
        guard selectedStatus != status, isCurrentAccount else { return }
        generation = UUID(); selectedStatus = status; outfits = []; hasLoaded = false; isLoading = false; isLoadingMore = false
        nextCursor = nil; busyIDs = []; pageCursors = []; openingID = nil
        await load()
    }
    func load() async {
        guard !isLoading, isCurrentAccount else { return }
        generation = UUID(); let request = generation
        isLoading = true; isLoadingMore = false; message = nil; openingID = nil; busyIDs = []
        defer { if generation == request { isLoading = false } }
        do {
            let page = try await client.fetchManagedOutfits(scope: scope, status: selectedStatus, cursor: nil)
            guard generation == request, isCurrentAccount else { return }
            outfits = page.items; nextCursor = page.nextCursor; pageCursors = []; hasLoaded = true
        } catch { if generation == request && isCurrentAccount { message = error.localizedDescription } }
    }
    func more() async {
        guard !isLoading, !isLoadingMore, let cursor = nextCursor, isCurrentAccount else { return }
        let request = generation; isLoadingMore = true; message = nil
        defer { if generation == request { isLoadingMore = false } }
        do {
            let page = try await client.fetchManagedOutfits(scope: scope, status: selectedStatus, cursor: cursor)
            guard generation == request, isCurrentAccount else { return }
            guard !pageCursors.contains(cursor), Set(outfits.map(\.id)).isDisjoint(with: page.items.map(\.id)) else { throw UFitOutfitContractError.page }
            outfits.append(contentsOf: page.items); nextCursor = page.nextCursor; pageCursors.insert(cursor)
        } catch { if generation == request && isCurrentAccount { message = error.localizedDescription } }
    }
    func open(_ id: String) async -> UFitManagedOutfitStore? {
        guard !busyIDs.contains(id), outfits.contains(where: { $0.id == id }), isCurrentAccount else { return nil }
        let request = generation; busyIDs.insert(id); openingID = id; message = nil
        defer { if generation == request { busyIDs.remove(id) } }
        do {
            let document = try await client.fetchManagedOutfit(id: id, scope: scope)
            guard generation == request, openingID == id, isCurrentAccount else { return nil }
            receive(document); return UFitManagedOutfitStore(document: document, collection: self)
        } catch { if generation == request && openingID == id && isCurrentAccount { message = error.localizedDescription }; return nil }
    }
    func receive(_ document: UFitManagedOutfit) {
        guard isCurrentAccount, scope == nil || scope == document.scope else { return }
        if selectedStatus != nil && selectedStatus != document.status { outfits.removeAll { $0.id == document.id }; return }
        if let index = outfits.firstIndex(where: { $0.id == document.id }) { outfits[index] = document }
    }
    func report(_ error: Error) { if isCurrentAccount { message = error.localizedDescription } }
}

@MainActor @Observable
final class UFitManagedOutfitStore {
    private(set) var document: UFitManagedOutfit
    private(set) var isLoading = false
    private(set) var isMutating = false
    private(set) var message: String?
    let collection: UFitManagedOutfitsStore
    private enum Copy { static let stale = String(localized: "Cette tenue a changé. Actualisez avant de continuer.") }
    init(document: UFitManagedOutfit, collection: UFitManagedOutfitsStore) { self.document = document; self.collection = collection }
    func load() async {
        guard !isLoading, !isMutating, collection.isCurrentAccount else { return }
        isLoading = true; message = nil
        defer { isLoading = false }
        do {
            let result = try await collection.client.fetchManagedOutfit(id: document.id, scope: collection.scope)
            if collection.isCurrentAccount { try receive(result) }
        } catch { if collection.isCurrentAccount { message = error.localizedDescription } }
    }
    func renewPhotoSource(_ imageID: String) async throws -> String {
        guard collection.isCurrentAccount, let image = document.images.first(where: { $0.id == imageID }) else { throw CancellationError() }
        let revision = document.revision
        let fresh = try await collection.client.fetchManagedOutfit(id: revision.id, scope: collection.scope)
        guard collection.isCurrentAccount, document.revision == revision else { throw CancellationError() }
        guard fresh.revision == revision, let renewed = fresh.images.first(where: { $0.id == imageID && $0.url == image.url }) else { throw UFitOutfitContractError.document }
        return renewed.displayUrl
    }
    func mutate(_ revision: UFitOutfitRevision, action: UFitOutfitAction) async {
        guard !isLoading, !isMutating, collection.isCurrentAccount else { return }
        guard revision == document.revision else { message = Copy.stale; return }
        isMutating = true; message = nil
        defer { isMutating = false }
        do {
            let result = try await collection.client.mutateOutfit(revision, action: action)
            if collection.isCurrentAccount { try receive(result) }
        } catch { if collection.isCurrentAccount { message = error.localizedDescription } }
    }
    func receive(_ result: UFitManagedOutfit) throws {
        guard collection.isCurrentAccount else { return }
        try result.validate(id: document.id, scope: document.scope)
        document = result; collection.receive(result); message = nil
    }
    func report(_ error: Error) { if collection.isCurrentAccount { message = error.localizedDescription } }
}
