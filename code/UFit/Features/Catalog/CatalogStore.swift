import Foundation
import Observation

@MainActor @Observable
final class UFitCatalogStore {
    let brandID: String?
    let title: String
    let subtitle: String
    let access: UFitCatalogAccess
    private(set) var products: [UFitManagedProduct] = []
    private(set) var selectedStatus: UFitCatalogStatus?
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
    @ObservationIgnored private let ownerUserID: String?
    init(brandID: String?, title: String, subtitle: String, access: UFitCatalogAccess, client: UFitAPIClient, session: UFitSessionStore, initialStatus: UFitCatalogStatus? = nil) {
        self.brandID = brandID; self.title = title; self.subtitle = subtitle; self.access = access; self.client = client; self.session = session
        ownerUserID = session.user?.id; selectedStatus = access == .moderator ? .underReview : initialStatus
    }
    var rows: [UFitCatalogRow] { products.map { $0.row() } }
    var isCurrentAccount: Bool { ownerUserID != nil && session.user?.id == ownerUserID }
    func cancelOpening() { openingID = nil }
    func filter(_ status: UFitCatalogStatus?) async {
        guard selectedStatus != status, isCurrentAccount else { return }
        generation = UUID(); selectedStatus = status; products = []; hasLoaded = false; isLoading = false; isLoadingMore = false
        nextCursor = nil; busyIDs = []; pageCursors = []; openingID = nil
        await load()
    }
    func load() async {
        guard !isLoading, isCurrentAccount else { return }
        generation = UUID(); let request = generation
        isLoading = true; isLoadingMore = false; message = nil; openingID = nil; busyIDs = []
        defer { if generation == request { isLoading = false } }
        do {
            let page = try await client.fetchCatalog(brandID: brandID, status: selectedStatus, cursor: nil)
            guard generation == request, isCurrentAccount else { return }
            products = page.items; nextCursor = page.nextCursor; pageCursors = []; hasLoaded = true
        } catch { if generation == request && isCurrentAccount { message = error.localizedDescription } }
    }
    func more() async {
        guard !isLoading, !isLoadingMore, let cursor = nextCursor, isCurrentAccount else { return }
        let request = generation
        isLoadingMore = true; message = nil
        defer { if generation == request { isLoadingMore = false } }
        do {
            let page = try await client.fetchCatalog(brandID: brandID, status: selectedStatus, cursor: cursor)
            guard generation == request, isCurrentAccount else { return }
            guard !pageCursors.contains(cursor), Set(products.map(\.id)).isDisjoint(with: page.items.map(\.id)) else { throw UFitCatalogContractError.page }
            products.append(contentsOf: page.items); nextCursor = page.nextCursor; pageCursors.insert(cursor)
        } catch { if generation == request && isCurrentAccount { message = error.localizedDescription } }
    }
    func open(_ id: String) async -> UFitCatalogProductStore? {
        guard !busyIDs.contains(id), products.contains(where: { $0.id == id }), isCurrentAccount else { return nil }
        let request = generation
        busyIDs.insert(id); openingID = id; message = nil
        defer { if generation == request { busyIDs.remove(id) } }
        do {
            let document = try await client.fetchManagedProduct(id: id, brandID: brandID)
            guard generation == request, openingID == id, isCurrentAccount else { return nil }
            receive(document)
            return UFitCatalogProductStore(document: document, catalog: self)
        } catch { if generation == request && openingID == id && isCurrentAccount { message = error.localizedDescription }; return nil }
    }
    func receive(_ document: UFitManagedProduct) {
        guard isCurrentAccount, brandID == nil || document.product.brandId == brandID else { return }
        if selectedStatus != nil && selectedStatus != document.product.status { products.removeAll { $0.id == document.id }; return }
        if let index = products.firstIndex(where: { $0.id == document.id }) { products[index] = document }
    }
    func report(_ error: Error) { if isCurrentAccount { message = error.localizedDescription } }
}

@MainActor @Observable
final class UFitCatalogProductStore {
    private(set) var document: UFitManagedProduct
    private(set) var isLoading = false
    private(set) var isMutating = false
    private(set) var message: String?
    let catalog: UFitCatalogStore
    init(document: UFitManagedProduct, catalog: UFitCatalogStore) { self.document = document; self.catalog = catalog }
    func load() async {
        guard !isLoading, !isMutating, catalog.isCurrentAccount else { return }
        isLoading = true; message = nil
        defer { isLoading = false }
        do {
            let result = try await catalog.client.fetchManagedProduct(id: document.id, brandID: catalog.brandID)
            if catalog.isCurrentAccount { try receive(result) }
        } catch { if catalog.isCurrentAccount { message = error.localizedDescription } }
    }
    func mutate(_ revision: UFitCatalogRevision, action: UFitCatalogAction, decision: UFitCatalogStatus? = nil, reason: String? = nil) async {
        guard !isLoading, !isMutating, catalog.isCurrentAccount else { return }
        guard revision == document.revision else { message = UFitCatalogContractError.stale.localizedDescription; return }
        isMutating = true; message = nil
        defer { isMutating = false }
        do {
            let result = try await catalog.client.mutateCatalogProduct(revision, action: action, decision: decision, reason: reason)
            if catalog.isCurrentAccount { try receive(result) }
        } catch { if catalog.isCurrentAccount { message = error.localizedDescription } }
    }
    func receive(_ result: UFitManagedProduct) throws {
        guard catalog.isCurrentAccount else { return }
        try result.validate(id: document.id, brand: document.product.brandId)
        document = result; catalog.receive(result); message = nil
    }
    func report(_ error: Error) { if catalog.isCurrentAccount { message = error.localizedDescription } }
}
