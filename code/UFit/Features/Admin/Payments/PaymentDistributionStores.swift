import Foundation
import Observation

@MainActor @Observable
final class UFitDistributionBrandsStore {
    var search = String()
    private(set) var rows = [UFitDistributionBrandRow]()
    private(set) var hasLoaded = false
    private(set) var isLoading = false
    private(set) var message: String?
    private(set) var nextCursor: String?
    private(set) var revoked = false
    private(set) var epoch = UUID()
    let session: UFitSessionStore
    @ObservationIgnored private let ownerID: String?
    @ObservationIgnored private var generation = UUID()
    @ObservationIgnored private var appliedSearch = String()
    @ObservationIgnored private var retryReset = true
    init(session: UFitSessionStore) { self.session = session; ownerID = session.user?.id }
    var isOwner: Bool { ownerID != nil && session.user?.id == ownerID && session.user?.canAdminister == true && session.user?.status == UFitAccountStatus.active.rawValue }
    var canRead: Bool { isOwner && !revoked }
    var invalidSearch: Bool { UFitServerTextInput.trimmed(search).utf16.count > UFitDistributionHTTP.searchMaximum }
    func cancelLoading() { generation = UUID(); isLoading = false }
    func revoke() { cancelLoading(); epoch = UUID(); revoked = true; rows = []; nextCursor = nil; hasLoaded = false; message = UFitDistributionCopy.access }
    func refresh() async { cancelLoading(); await load() }
    func retry() async { await load(reset: retryReset) }
    func searchChanged() async {
        let term = UFitServerTextInput.trimmed(search)
        guard term != appliedSearch || !hasLoaded else { return }
        cancelLoading(); rows = []; hasLoaded = false; nextCursor = nil; message = nil
        let request = generation
        do { if !term.isEmpty { try await Task.sleep(for: UFitDistributionHTTP.searchDebounce) } } catch { return }
        guard generation == request else { return }; await load()
    }
    func load(reset: Bool = true) async {
        guard isOwner, !isLoading, reset || nextCursor != nil else { return }
        let request = generation, access = epoch, term = reset ? UFitServerTextInput.trimmed(search) : appliedSearch
        let cursor = reset ? nil : nextCursor, existing = reset ? [] : rows
        retryReset = reset
        if reset { rows = []; hasLoaded = false; nextCursor = nil }
        guard !invalidSearch else { message = UFitDistributionCopy.searchTooLong; return }
        isLoading = true; message = nil
        defer { if generation == request { isLoading = false } }
        do {
            let result = try await session.api.fetchDistributionBrands(search: term, cursor: cursor)
            guard generation == request, epoch == access, isOwner else { return }
            guard Set(existing.map(\.id)).isDisjoint(with: Set(result.items.map(\.id))) else { throw UFitDistributionBoundaryFailure.document }
            rows = existing + result.items; nextCursor = result.nextCursor; hasLoaded = true; appliedSearch = term; revoked = false
        } catch {
            guard generation == request, epoch == access, isOwner, !Task.isCancelled else { return }
            if UFitDistributionError.revoked(error) { revoke() } else { message = UFitDistributionError.message(error) }
        }
    }
    func accept(_ document: UFitDistributionDocument) {
        guard canRead, let index = rows.firstIndex(where: { $0.id == document.brand.id }) else { return }
        rows[index].brand = document.brand; rows[index].current = document.current
    }
}

@MainActor @Observable
final class UFitDistributionDetailStore {
    let brandID: String; let collection: UFitDistributionBrandsStore
    private(set) var isLoading = false
    private(set) var message: String?
    private var received: UFitDistributionDocument?
    @ObservationIgnored private var generation = UUID()
    init(brandID: String, collection: UFitDistributionBrandsStore) { self.brandID = brandID; self.collection = collection }
    var document: UFitDistributionDocument? { collection.canRead ? received : nil }
    var canEdit: Bool { document != nil && !isLoading && message == nil }
    func cancelLoading() { generation = UUID(); isLoading = false }
    func refresh() async { cancelLoading(); await load() }
    func accept(_ document: UFitDistributionDocument) {
        guard collection.canRead, document.brand.id == brandID else { return }
        received = document; message = nil; collection.accept(document)
    }
    func missing() { received = nil; message = UFitDistributionCopy.missing }
    func load() async {
        guard collection.canRead, !isLoading else { return }
        let request = generation, access = collection.epoch
        isLoading = true; message = nil
        defer { if generation == request { isLoading = false } }
        do {
            let result = try await collection.session.api.fetchDistribution(brandID: brandID)
            guard generation == request, access == collection.epoch, collection.canRead else { return }; accept(result)
        } catch {
            guard generation == request, access == collection.epoch, collection.canRead, !Task.isCancelled else { return }
            if UFitDistributionError.revoked(error) { collection.revoke() }
            else if UFitDistributionError.code(error, equals: UFitDistributionHTTP.brandMissing) { missing() }
            else { message = UFitDistributionError.message(error) }
        }
    }
}

@MainActor @Observable
final class UFitDistributionHistoryStore {
    let detail: UFitDistributionDetailStore
    private(set) var rows = [UFitDistributionRevision]()
    private(set) var hasLoaded = false
    private(set) var isLoading = false
    private(set) var message: String?
    private(set) var nextCursor: String?
    @ObservationIgnored private var generation = UUID()
    @ObservationIgnored private var retryReset = true
    init(detail: UFitDistributionDetailStore) { self.detail = detail }
    func cancelLoading() { generation = UUID(); isLoading = false }
    func retry() async { await load(reset: retryReset) }
    func load(reset: Bool = true) async {
        guard detail.collection.canRead, !isLoading, reset || nextCursor != nil else { return }
        let request = generation, access = detail.collection.epoch, cursor = reset ? nil : nextCursor
        let existing = reset ? [] : rows
        retryReset = reset
        if reset { rows = []; nextCursor = nil; hasLoaded = false }
        isLoading = true; message = nil
        defer { if generation == request { isLoading = false } }
        do {
            let result = try await detail.collection.session.api.fetchDistributionHistory(brandID: detail.brandID, cursor: cursor, after: existing.last?.revision)
            guard generation == request, access == detail.collection.epoch, detail.collection.canRead else { return }
            guard Set(existing.map(\.id)).isDisjoint(with: Set(result.items.map(\.id))) else { throw UFitDistributionBoundaryFailure.document }
            rows = existing + result.items; nextCursor = result.nextCursor; hasLoaded = true
        } catch {
            guard generation == request, access == detail.collection.epoch, detail.collection.canRead, !Task.isCancelled else { return }
            if UFitDistributionError.revoked(error) { detail.collection.revoke() }
            else { message = UFitDistributionError.message(error) }
        }
    }
}
