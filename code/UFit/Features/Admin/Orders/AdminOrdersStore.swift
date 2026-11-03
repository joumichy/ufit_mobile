import Foundation
import Observation

@MainActor @Observable
final class UFitAdminOrdersStore {
    var search = String()
    var status: UFitOrderLifecycle?
    var currency: String?
    var shipmentStatus: UFitShipmentLifecycle?
    var visibleRowID: String?
    private(set) var rows = [UFitAdminOrderSummary]()
    private(set) var page: UFitAdminOrderPage?
    private(set) var isLoading = false
    private(set) var message: String?
    private(set) var needsRefresh = false
    private(set) var messageAtEnd = false
    private(set) var revoked = false
    private(set) var epoch = UUID()
    let session: UFitSessionStore
    @ObservationIgnored private let ownerID: String?
    @ObservationIgnored private var generation = UUID()
    @ObservationIgnored private var applied = UFitAdminOrderQuery()
    @ObservationIgnored private var retryReset = true
    private var knownCurrencies = [String]()
    init(session: UFitSessionStore) { self.session = session; ownerID = session.user?.id }
    var isOwner: Bool { ownerID != nil && session.user?.id == ownerID && session.user?.canAdminister == true && session.user?.status == UFitAccountStatus.active.rawValue }
    var canRead: Bool { isOwner && !revoked }
    var selection: UFitAdminOrderQuery { .init(search: UFitServerTextInput.trimmed(search), status: status, currency: currency, shipmentStatus: shipmentStatus) }
    var hasMore: Bool { canRead && !needsRefresh && page?.nextCursor != nil }
    var hasLoaded: Bool { canRead && page != nil }
    var currencies: [String] { canRead ? knownCurrencies : [] }
    func cancelLoading() { generation = UUID(); isLoading = false }
    func reset() { search = String(); status = nil; currency = nil; shipmentStatus = nil }
    func refresh() async { cancelLoading(); await load() }
    func retry() async { cancelLoading(); await load(reset: retryReset || needsRefresh) }
    func revoke() {
        cancelLoading(); epoch = UUID(); revoked = true; rows = []; page = nil; visibleRowID = nil; messageAtEnd = false
        knownCurrencies = []; retryReset = true; needsRefresh = false; message = UFitAdminOrdersCopy.access
    }
    func selectionChanged() async {
        guard selection != applied || !hasLoaded else { return }
        let debounce = selection.status == applied.status && selection.currency == applied.currency && selection.shipmentStatus == applied.shipmentStatus && !selection.search.isEmpty
        cancelLoading(); clear(); let request = generation
        do { if debounce { try await Task.sleep(for: UFitAdminOrdersCopy.searchDebounce) } } catch { return }
        guard generation == request else { return }
        await load()
    }
    func load(reset: Bool = true) async {
        guard isOwner, !isLoading, reset || hasMore else { return }
        let request = generation, access = epoch, query = reset ? selection : applied, previous = reset ? nil : page
        let existing = reset ? [] : rows
        retryReset = reset
        if reset { clear() }
        isLoading = true; message = nil
        defer { if generation == request { isLoading = false } }
        do {
            let result = try await session.api.fetchAdminOrders(query: query, cursor: previous?.nextCursor, revision: previous?.revision)
            guard generation == request, epoch == access, isOwner else { return }
            guard Set(existing.map(\.id)).isDisjoint(with: Set(result.items.map(\.id))), previous == nil || previous?.totalCount == result.totalCount else { throw UFitAdminOrdersFailure.page }
            rows = existing + result.items; page = result; knownCurrencies = result.currencies; applied = query; revoked = false
        } catch {
            guard generation == request, epoch == access, isOwner else { return }
            if UFitAdminOrdersError.revoked(error) { revoke(); return }
            needsRefresh = UFitAdminOrdersError.changed(error); messageAtEnd = !reset
            message = UFitAdminOrdersError.message(error, resource: .list)
        }
    }
    private func clear() { rows = []; page = nil; visibleRowID = nil; needsRefresh = false; message = nil; messageAtEnd = false }
}

@MainActor @Observable
final class UFitAdminOrderDetailStore {
    let id: String; let collection: UFitAdminOrdersStore
    private(set) var document: UFitAdminOrderDetail?
    private(set) var isLoading = false
    private(set) var message: String?
    @ObservationIgnored private var generation = UUID()
    init(id: String, collection: UFitAdminOrdersStore) { self.id = id; self.collection = collection }
    func cancelLoading() { generation = UUID(); isLoading = false }
    func load() async {
        guard collection.canRead, !isLoading else { return }
        let request = generation, access = collection.epoch
        isLoading = true; document = nil; message = nil
        defer { if request == generation { isLoading = false } }
        do {
            let result = try await collection.session.api.fetchAdminOrder(id: id)
            guard generation == request, collection.epoch == access, collection.canRead else { return }
            document = result
        } catch {
            guard generation == request, collection.epoch == access, collection.canRead else { return }
            if UFitAdminOrdersError.revoked(error) { collection.revoke() }
            message = UFitAdminOrdersError.message(error, resource: .detail)
        }
    }
}

@MainActor @Observable
final class UFitAdminOrderReturnsStore {
    let orderID: String; let reference: String; let collection: UFitAdminOrdersStore
    private(set) var rows = [UFitReturnSummaryDTO]()
    private(set) var hasLoaded = false
    private(set) var isLoading = false
    private(set) var message: String?
    private(set) var nextCursor: String?
    private(set) var messageAtEnd = false
    @ObservationIgnored private var generation = UUID()
    @ObservationIgnored private var retryReset = true
    init(orderID: String, reference: String, collection: UFitAdminOrdersStore) { self.orderID = orderID; self.reference = reference; self.collection = collection }
    func cancelLoading() { generation = UUID(); isLoading = false }
    func retry() async { cancelLoading(); await load(reset: retryReset) }
    func refresh() async { cancelLoading(); await load() }
    func load(reset: Bool = true) async {
        guard collection.canRead, !isLoading, reset || nextCursor != nil else { return }
        let request = generation, access = collection.epoch, cursor = reset ? nil : nextCursor
        if reset { rows = []; nextCursor = nil; hasLoaded = false; messageAtEnd = false }
        retryReset = reset; isLoading = true; message = nil
        defer { if generation == request { isLoading = false } }
        do {
            let result = try await collection.session.api.fetchAdminOrderReturns(id: orderID, cursor: cursor)
            guard generation == request, collection.epoch == access, collection.canRead else { return }
            let merged = reset ? result.items : rows + result.items
            guard Set(merged.map(\.id)).count == merged.count else { throw UFitReturnContractError.page }
            rows = merged; nextCursor = result.nextCursor; hasLoaded = true
        } catch {
            guard generation == request, collection.epoch == access, collection.canRead else { return }
            if UFitAdminOrdersError.revoked(error) { rows = []; nextCursor = nil; collection.revoke() }
            message = UFitAdminOrdersError.message(error, resource: .returns); messageAtEnd = !reset
        }
    }
}

enum UFitAdminOrdersError {
    enum Resource { case list, detail, returns }
    static func revoked(_ error: Error) -> Bool {
        if case UFitAPIError.authenticationRequired = error { return true }
        guard case UFitAPIError.requestFailed(let status, _, _) = error else { return false }
        return status == UFitAdminOrdersHTTP.unauthorized || status == UFitAdminOrdersHTTP.forbidden
    }
    static func changed(_ error: Error) -> Bool {
        guard case UFitAPIError.requestFailed(let status, _, let code) = error else { return false }
        return status == UFitAdminOrdersHTTP.changed && code == UFitAdminOrdersHTTP.changedCode
    }
    static func message(_ error: Error, resource: Resource) -> String {
        if revoked(error) { return UFitAdminOrdersCopy.access }
        if changed(error) { return UFitAdminOrdersCopy.changed }
        if case UFitAPIError.requestFailed(let status, _, _) = error, status == UFitAdminOrdersHTTP.missing { return UFitAdminOrdersCopy.missing }
        if error is UFitAdminOrdersFailure || error is UFitReturnContractError { return error.localizedDescription }
        switch resource { case .list: return UFitAdminOrdersCopy.listFailure; case .detail: return UFitAdminOrdersCopy.detailFailure; case .returns: return UFitAdminOrdersCopy.returnsFailure }
    }
}
