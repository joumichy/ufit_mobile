import Foundation
import Observation

enum WorkspaceFinanceResponse {
    static let unauthorized = 401; static let forbidden = 403
    static let unavailableStatuses = 500...599
    private enum Copy {
        static let verification = String(localized: "Les données financières nécessitent une vérification. Réessayez plus tard.")
        static let unavailable = String(localized: "Les données financières sont indisponibles. Réessayez.")
        static let offline = String(localized: "Connexion indisponible. Vérifiez votre réseau et réessayez.")
        static let access = String(localized: "L’accès à cet espace a changé. Actualisez pour vérifier vos droits.")
    }
    static func revoked(_ error: Error) -> Bool {
        guard case UFitAPIError.requestFailed(let status, _, _) = error else { return false }
        return status == unauthorized || status == forbidden
    }
    static func message(_ error: Error) -> String {
        if revoked(error) { return Copy.access }
        if case UFitAPIError.requestFailed(_, _, let code) = error, code == UFitWorkspaceFinanceContract.persistedCode {
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
    var revenuePeriod: UFitRevenuePeriod = .month
    private(set) var revenue: UFitWorkspaceRevenueDTO?
    private(set) var isRevenueLoading = false
    private(set) var revenueMessage: String?
    @ObservationIgnored private let session: UFitSessionStore
    @ObservationIgnored private let userID: String
    @ObservationIgnored private var generation = UUID()
    @ObservationIgnored private var revenueGeneration = UUID()
    var isCurrentAccount: Bool { session.user?.id == userID }
    func revokeFinancialAccess(_ error: Error) {
        cancelLoading(); document = nil; revenue = nil
        message = WorkspaceFinanceResponse.message(error); revenueMessage = message
    }
    init(workspace: UFitWorkspaceReference, session: UFitSessionStore, userID: String) {
        self.workspace = workspace; self.session = session; self.userID = userID
    }
    func cancelLoading() { generation = UUID(); isLoading = false; revenueGeneration = UUID(); isRevenueLoading = false }
    func changeRevenuePeriod() async {
        revenueGeneration = UUID(); isRevenueLoading = false
        await loadRevenue()
    }
    func loadRevenue() async {
        guard !isRevenueLoading, isCurrentAccount else { return }
        let request = revenueGeneration
        let period = revenuePeriod
        isRevenueLoading = true; revenue = nil; revenueMessage = nil
        defer { if revenueGeneration == request { isRevenueLoading = false } }
        do {
            let result = try await session.api.fetchWorkspaceRevenue(workspace, period: period)
            guard revenueGeneration == request, isCurrentAccount, period == revenuePeriod else { return }
            revenue = result
        } catch {
            guard revenueGeneration == request, isCurrentAccount else { return }
            revenueMessage = WorkspaceFinanceResponse.message(error)
            if WorkspaceFinanceResponse.revoked(error) {
                generation = UUID(); isLoading = false; document = nil
                message = revenueMessage
            }
        }
    }
    func refresh() async {
        async let dashboard: Void = load()
        async let chart: Void = loadRevenue()
        _ = await (dashboard, chart)
    }
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
    var selectedState: UFitCommissionRelease.State?
    private(set) var entries = [UFitCommissionEntry]()
    private(set) var hasLoaded = false
    private(set) var isLoading = false
    private(set) var message: String?
    private(set) var hasMore = false
    private(set) var asOf: UFitTimestamp?
    @ObservationIgnored private let session: UFitSessionStore
    @ObservationIgnored private let userID: String
    @ObservationIgnored private let creatorID: String
    @ObservationIgnored private var generation = UUID()
    @ObservationIgnored private var nextCursor: String?
    @ObservationIgnored private var revision: String?
    @ObservationIgnored private var rows = [UFitCommissionEntryDTO]()
    @ObservationIgnored private var retryRefresh = true
    var isCurrentAccount: Bool { session.user?.id == userID && session.user?.roles.contains(.creator) == true }
    init(name: String, creatorID: String, session: UFitSessionStore, userID: String) {
        self.name = name; self.creatorID = creatorID; self.session = session; self.userID = userID
    }
    func cancelLoading() { generation = UUID(); isLoading = false }
    func retry() async { await load(refresh: retryRefresh) }
    func load(refresh: Bool = true) async {
        guard !isLoading, isCurrentAccount, refresh || nextCursor != nil else { return }
        let request = generation
        retryRefresh = refresh
        if refresh { rows = []; entries = []; nextCursor = nil; revision = nil; hasLoaded = false; hasMore = false; asOf = nil }
        isLoading = true; message = nil
        defer { if generation == request { isLoading = false } }
        do {
            let result = try await session.api.fetchCreatorCommissions(creatorID: creatorID, state: selectedState, cursor: nextCursor, revision: revision)
            guard generation == request, isCurrentAccount else { return }
            try result.validateAppend(existing: rows, expectedLimit: UFitCommissionLedgerContract.limit, expectedRevision: revision)
            let combined = rows + result.items
            entries = try combined.map { try $0.presentation() }; rows = combined
            revision = result.revision; nextCursor = result.nextCursor; asOf = result.asOf
            hasLoaded = true; hasMore = nextCursor != nil
        } catch {
            guard generation == request, isCurrentAccount else { return }
            if UFitCommissionLedgerCopy.isRevoked(error) { rows = []; entries = []; revision = nil; nextCursor = nil; hasLoaded = false; hasMore = false; asOf = nil; retryRefresh = true }
            if UFitCommissionLedgerCopy.isChanged(error) { retryRefresh = true }
            message = UFitCommissionLedgerCopy.message(error)
        }
    }
}
