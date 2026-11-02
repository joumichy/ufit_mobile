import Foundation
import Observation

@MainActor @Observable
final class UFitEditorialStore {
    private(set) var collections: [UFitEditorialCollection] = []
    private(set) var isLoading = false
    private(set) var hasLoaded = false
    private(set) var message: String?
    private(set) var isLoadingMore = false
    private(set) var moreError: String?
    var visibleCollectionID: String?
    var collection: UFitEditorialCollectionStore?
    var product: UFitPublicProductStore?
    @ObservationIgnored let client: UFitAPIClient
    @ObservationIgnored private var generation = UUID()
    @ObservationIgnored private var nextCursor: String?
    @ObservationIgnored private var consumedCursors = Set<String>()
    var hasMore: Bool { nextCursor != nil }
    init(client: UFitAPIClient) { self.client = client }
    func load() async {
        guard !isLoading else { return }
        let request = UUID(); generation = request
        isLoading = true; message = nil; moreError = nil; isLoadingMore = false
        defer { if generation == request { isLoading = false } }
        do {
            let page = try await client.fetchEditorialCollections()
            try Task.checkCancellation()
            guard generation == request else { return }
            collections = page.items; nextCursor = page.nextCursor; consumedCursors = []; hasLoaded = true
            if let visibleCollectionID, !collections.contains(where: { $0.id == visibleCollectionID }) { self.visibleCollectionID = nil }
        } catch is CancellationError {} catch { if generation == request { message = UFitEditorialCopy.loadFailed } }
    }
    func more() async {
        guard !isLoading, !isLoadingMore, message == nil, let cursor = nextCursor else { return }
        let request = generation; isLoadingMore = true; moreError = nil
        defer { if generation == request { isLoadingMore = false } }
        do {
            let page = try await client.fetchEditorialCollections(cursor: cursor)
            try Task.checkCancellation()
            guard generation == request else { return }
            guard !consumedCursors.contains(cursor), Set(collections.map(\.id)).isDisjoint(with: page.items.map(\.id)) else { throw UFitEditorialFailure.contract }
            collections.append(contentsOf: page.items); nextCursor = page.nextCursor; consumedCursors.insert(cursor)
        } catch is CancellationError {} catch { if generation == request { moreError = UFitEditorialCopy.moreFailed } }
    }
    func open(_ value: UFitEditorialCollection) { collection = UFitEditorialCollectionStore(id: value.id, client: client) }
    func openProduct(_ value: UFitEditorialEntry, session: UFitSessionStore) {
        collection?.cancelOpening()
        product = UFitPublicProductStore(id: value.contentId, client: client, session: session)
    }
    func back() -> Bool {
        if product != nil { product = nil; return true }
        if let collection {
            collection.cancelOpening()
            if collection.isUnavailable {
                collections.removeAll { $0.id == collection.id }; hasLoaded = false
            } else if let current = collection.collection, let index = collections.firstIndex(where: { $0.id == current.id }) {
                collections[index] = current
            }
            self.collection = nil; return true
        }
        return false
    }
}

@MainActor @Observable
final class UFitEditorialCollectionStore {
    let id: String
    private(set) var collection: UFitEditorialCollection?
    private(set) var entries: [UFitEditorialEntry] = []
    private(set) var isLoading = false
    private(set) var hasLoaded = false
    private(set) var message: String?
    private(set) var isUnavailable = false
    private(set) var isLoadingMore = false
    private(set) var moreError: String?
    private(set) var busyEntries = Set<String>()
    private(set) var entryErrors = [String: String]()
    var visibleEntryID: String?
    @ObservationIgnored private let client: UFitAPIClient
    @ObservationIgnored private var generation = UUID()
    @ObservationIgnored private var opening = UUID()
    @ObservationIgnored private var nextCursor: String?
    @ObservationIgnored private var consumedCursors = Set<String>()
    var hasMore: Bool { nextCursor != nil }
    init(id: String, client: UFitAPIClient) { self.id = id; self.client = client }
    func load() async {
        guard !isLoading else { return }
        let request = UUID(); generation = request; cancelOpening()
        isLoading = true; hasLoaded = false; isUnavailable = false; message = nil; moreError = nil; isLoadingMore = false
        defer { if generation == request { isLoading = false } }
        do {
            let value = try await client.fetchEditorialCollection(id: id)
            let page = try await client.fetchEditorialItems(id: id, version: value.version)
            try Task.checkCancellation()
            guard generation == request else { return }
            collection = value; entries = page.items; nextCursor = page.nextCursor; consumedCursors = []
            hasLoaded = true; isUnavailable = false; entryErrors = [:]
            if let visibleEntryID, !entries.contains(where: { $0.id == visibleEntryID }) { self.visibleEntryID = nil }
        } catch is CancellationError {} catch {
            if generation == request {
                if UFitEditorialFailure.status(error) == UFitEditorialHTTP.missing { unavailable() }
                else { message = UFitEditorialFailure.status(error) == UFitEditorialHTTP.changed ? UFitEditorialCopy.changed : UFitEditorialCopy.collectionFailed }
            }
        }
    }
    func more() async {
        guard !isLoading, !isLoadingMore, message == nil, let cursor = nextCursor, let collection else { return }
        let request = generation; isLoadingMore = true; moreError = nil
        defer { if generation == request { isLoadingMore = false } }
        do {
            let page = try await client.fetchEditorialItems(id: id, version: collection.version, cursor: cursor)
            try Task.checkCancellation()
            guard generation == request else { return }
            guard !consumedCursors.contains(cursor), Set(entries.map(\.id)).isDisjoint(with: page.items.map(\.id)),
                  entries.last == nil || page.items.first == nil || entries.last!.position < page.items.first!.position else { throw UFitEditorialFailure.contract }
            entries.append(contentsOf: page.items); nextCursor = page.nextCursor; consumedCursors.insert(cursor)
        } catch is CancellationError {} catch {
            if generation == request {
                if UFitEditorialFailure.status(error) == UFitEditorialHTTP.missing { unavailable() }
                else if UFitEditorialFailure.status(error) == UFitEditorialHTTP.changed { message = UFitEditorialCopy.changed }
                else { moreError = UFitEditorialCopy.moreFailed }
            }
        }
    }
    func openOutfit(_ entry: UFitEditorialEntry) async -> Outfit? {
        guard entry.itemType == .outfit, !busyEntries.contains(entry.id) else { return nil }
        let request = UUID(); opening = request; busyEntries.insert(entry.id); entryErrors[entry.id] = nil
        defer { busyEntries.remove(entry.id) }
        do {
            let detail = try await client.fetchOutfitDetail(id: entry.contentId)
            try Task.checkCancellation()
            guard opening == request else { return nil }
            return detail.toOutfit()
        } catch is CancellationError { return nil }
        catch { if opening == request { entryErrors[entry.id] = UFitEditorialCopy.openingFailed }; return nil }
    }
    func cancelOpening() { opening = UUID() }
    private func unavailable() {
        collection = nil; entries = []; nextCursor = nil; isUnavailable = true; hasLoaded = true; message = nil; moreError = nil
    }
}
