import Foundation

private enum WorkspaceRevenueHTTP {
    static let get = "GET"
    static let creator = "creators/me/revenue"
    static let brands = "brands/"
    static let revenue = "/revenue"
    static let period = "period"
}

extension UFitAPIClient {
    func fetchWorkspaceRevenue(_ workspace: UFitWorkspaceReference, period: UFitRevenuePeriod) async throws -> UFitWorkspaceRevenueDTO {
        let path = workspace.isCreator ? WorkspaceRevenueHTTP.creator : WorkspaceRevenueHTTP.brands + workspace.profileID + WorkspaceRevenueHTTP.revenue
        let result: UFitWorkspaceRevenueDTO = try await send(WorkspaceRevenueHTTP.get, path: path, query: [URLQueryItem(name: WorkspaceRevenueHTTP.period, value: period.rawValue)], requiresAuth: true)
        try result.validate(workspace: workspace, period: period)
        return result
    }
}
