import Foundation
import Observation

@MainActor @Observable
final class UFitWorkspaceTransfersStore {
    enum Operation { case idle, loading, refreshing, more }
    let dashboard: UFitWorkspaceDashboardStore
    @ObservationIgnored private let session: UFitSessionStore
    @ObservationIgnored private var generation = UUID()
    private var received: UFitWorkspaceTransferPage?
    private var receivedEntries = [UFitWorkspaceTransferEntry]()
    private(set) var operation = Operation.idle
    private(set) var message: String?
    private(set) var accessRevoked = false
    private(set) var failureAtEnd = false
    private(set) var retryRefresh = true
    private(set) var readFailed = false
    init(dashboard: UFitWorkspaceDashboardStore, session: UFitSessionStore) { self.dashboard = dashboard; self.session = session }
    var workspace: UFitWorkspaceReference { dashboard.workspace }
    var canRead: Bool { dashboard.isCurrentAccount && !accessRevoked }
    var document: UFitWorkspaceTransferPage? { canRead ? received : nil }
    var entries: [UFitWorkspaceTransferEntry] { canRead ? receivedEntries : [] }
    var isLoading: Bool { operation != .idle }
    var hasMore: Bool { document?.nextCursor != nil }
    func cancelLoading() { generation = UUID(); operation = .idle }
    func refresh() async { cancelLoading(); await load() }
    func retry() async { await load(refresh: retryRefresh) }
    func load(refresh: Bool = true) async {
        guard canRead, !isLoading, refresh || hasMore else { return }
        let request = generation, previous = refresh ? nil : document
        operation = refresh ? (received == nil ? .loading : .refreshing) : .more
        retryRefresh = refresh; failureAtEnd = false; message = nil
        defer { if generation == request { operation = .idle } }
        do {
            let result = try await session.api.fetchWorkspaceTransfers(workspace, cursor: previous?.nextCursor, revision: previous?.revision)
            guard generation == request, canRead else { return }
            let existing = refresh ? [] : receivedEntries
            try result.validateAppend(existing: existing, previous: previous)
            received = result; receivedEntries = existing + result.items; readFailed = false
        } catch {
            guard generation == request, canRead, !Task.isCancelled else { return }
            if WorkspaceFinanceResponse.revoked(error) || isMissing(error) {
                received = nil; receivedEntries = []; accessRevoked = true; dashboard.revokeFinancialAccess(error); return
            }
            readFailed = true; failureAtEnd = !refresh
            if case UFitAPIError.requestFailed(_, _, let code) = error, code == UFitWorkspaceTransfersHTTP.changed {
                retryRefresh = true; message = UFitWorkspaceTransfersCopy.changed
            } else if error is UFitWorkspaceTransferFailure || error is DecodingError {
                retryRefresh = true; message = UFitWorkspaceTransfersCopy.invalid
            } else if case UFitAPIError.requestFailed(_, _, let code) = error, code == UFitWorkspaceTransfersHTTP.persisted {
                retryRefresh = true; message = UFitWorkspaceTransfersCopy.invalid
            } else { message = WorkspaceFinanceResponse.message(error) }
        }
    }
    private func isMissing(_ error: Error) -> Bool {
        if case UFitAPIError.requestFailed(let status, _, _) = error { return status == UFitWorkspaceTransfersHTTP.missing }
        return false
    }
}
