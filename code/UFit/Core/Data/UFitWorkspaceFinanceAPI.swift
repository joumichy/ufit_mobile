import Foundation

private enum WorkspaceFinanceHTTP {
    static let get = "GET"
    static let creatorDashboard = "creators/me/dashboard"
    static let creatorCommissions = "creators/me/commissions"
    static let brands = "brands/"; static let dashboard = "/dashboard"
    static let limit = "limit"; static let offset = "offset"
}
extension UFitAPIClient {
    func fetchWorkspaceDashboard(_ workspace: UFitWorkspaceReference, userID: String) async throws -> UFitWorkspaceDashboardDocument {
        if workspace.isCreator {
            let value: UFitCreatorDashboardDTO = try await send(WorkspaceFinanceHTTP.get, path: WorkspaceFinanceHTTP.creatorDashboard, requiresAuth: true)
            try value.validate(workspace: workspace, userID: userID)
            return .creator(value)
        }
        let value: UFitBrandDashboardDTO = try await send(WorkspaceFinanceHTTP.get, path: WorkspaceFinanceHTTP.brands + workspace.profileID + WorkspaceFinanceHTTP.dashboard, requiresAuth: true)
        try value.validate(workspace: workspace)
        return .brand(value)
    }
    func fetchWorkspaceCommissions(offset: Int) async throws -> UFitWorkspaceCommissionPageDTO {
        let value: UFitWorkspaceCommissionPageDTO = try await send(WorkspaceFinanceHTTP.get, path: WorkspaceFinanceHTTP.creatorCommissions,
            query: [URLQueryItem(name: WorkspaceFinanceHTTP.limit, value: String(UFitWorkspaceFinanceContract.pageLimit)),
                    URLQueryItem(name: WorkspaceFinanceHTTP.offset, value: String(offset))], requiresAuth: true)
        try value.validate(limit: UFitWorkspaceFinanceContract.pageLimit, offset: offset)
        return value
    }
}
