import Foundation
import Observation

private enum WorkspaceFinanceResponse {
    static let unauthorized = 401; static let forbidden = 403
    static let unavailableStatuses = 500...599
    private enum Copy {
        static let verification = String(localized: "Les données financières nécessitent une vérification. Réessayez plus tard.")
        static let unavailable = String(localized: "Les données financières sont indisponibles. Réessayez.")
        static let offline = String(localized: "Connexion indisponible. Vérifiez votre réseau et réessayez.")
    }
    static let persisted = "workspace_finance_persisted_invalid"
    static func revoked(_ error: Error) -> Bool {
        guard case UFitAPIError.requestFailed(let status, _, _) = error else { return false }
        return status == unauthorized || status == forbidden
    }
    static func message(_ error: Error) -> String {
        if case UFitAPIError.requestFailed(_, _, let code) = error, code == persisted {
            return Copy.verification
        }
        if case UFitAPIError.requestFailed(let status, _, _) = error, unavailableStatuses.contains(status) {
            return Copy.unavailable
        }
        if error is URLError { return Copy.offline }
        return error.localizedDescription
    }
}
@MainActor @Observable
final class UFitWorkspaceDashboardStore {
    let workspace: UFitWorkspaceReference
    private(set) var document: UFitWorkspaceDashboardPresentation?
    private(set) var isLoading = false
    private(set) var message: String?
    @ObservationIgnored private let session: UFitSessionStore
    @ObservationIgnored private let userID: String
    @ObservationIgnored private var generation = UUID()
    var isCurrentAccount: Bool { session.user?.id == userID }
    init(workspace: UFitWorkspaceReference, session: UFitSessionStore, userID: String) {
        self.workspace = workspace; self.session = session; self.userID = userID
    }
    func cancelLoading() { generation = UUID(); isLoading = false }
    func load() async {
        guard !isLoading, isCurrentAccount else { return }
        let request = generation
        isLoading = true; message = nil; document = nil
        defer { if generation == request { isLoading = false } }
        do {
            let result = try await session.api.fetchWorkspaceDashboard(workspace, userID: userID)
            guard generation == request, isCurrentAccount else { return }
            document = result.presentation
        } catch { if generation == request && isCurrentAccount { document = nil; message = WorkspaceFinanceResponse.message(error) } }
    }
}
@MainActor @Observable
final class UFitWorkspaceCommissionsStore {
    let name: String
    private(set) var entries = [UFitWorkspaceCommissionEntry]()
    private(set) var hasLoaded = false
    private(set) var isLoading = false
    private(set) var message: String?
    private(set) var hasMore = false
    @ObservationIgnored private let session: UFitSessionStore
    @ObservationIgnored private let userID: String
    @ObservationIgnored private var generation = UUID()
    @ObservationIgnored private var nextOffset: Int?
    @ObservationIgnored private var total: Int?
    @ObservationIgnored private var rows = [UFitWorkspaceCommissionDTO]()
    @ObservationIgnored private var retryRefresh = true
    var isCurrentAccount: Bool { session.user?.id == userID }
    init(name: String, session: UFitSessionStore, userID: String) { self.name = name; self.session = session; self.userID = userID }
    func cancelLoading() { generation = UUID(); isLoading = false }
    func retry() async { await load(refresh: retryRefresh) }
    func load(refresh: Bool = true) async {
        guard !isLoading, isCurrentAccount, refresh || nextOffset != nil else { return }
        let request = generation
        let offset = refresh ? Int.zero : nextOffset!
        retryRefresh = refresh
        if refresh { rows = []; entries = []; nextOffset = nil; total = nil; hasLoaded = false; hasMore = false }
        isLoading = true; message = nil
        defer { if generation == request { isLoading = false } }
        do {
            let result = try await session.api.fetchWorkspaceCommissions(offset: offset)
            guard generation == request, isCurrentAccount else { return }
            guard total == nil || total == result.page.total else { throw UFitWorkspaceFinanceFailure.page }
            let combined = rows + result.items
            guard Set(combined.map(\.id)).count == combined.count,
                zip(combined, combined.dropFirst()).allSatisfy({ first, second in
                    first.createdAt.value > second.createdAt.value || (first.createdAt == second.createdAt && first.id > second.id)
                }) else { throw UFitWorkspaceFinanceFailure.page }
            let rendered = try combined.map { try $0.presentation() }
            rows = combined; entries = rendered; total = result.page.total; nextOffset = result.page.nextOffset
            hasLoaded = true; hasMore = nextOffset != nil
        } catch {
            guard generation == request, isCurrentAccount else { return }
            if WorkspaceFinanceResponse.revoked(error) {
                rows = []; entries = []; total = nil; nextOffset = nil; hasLoaded = false; hasMore = false; retryRefresh = true
            }
            if error is UFitWorkspaceFinanceFailure { retryRefresh = true }
            message = WorkspaceFinanceResponse.message(error)
        }
    }
}
