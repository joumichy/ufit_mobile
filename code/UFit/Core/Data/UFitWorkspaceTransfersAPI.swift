import Foundation

enum UFitWorkspaceTransfersHTTP {
    static let get = "GET", creator = "creators/me/transfers", brands = "brands/", history = "/transfers"
    static let limitKey = "limit", cursorKey = "cursor", revisionKey = "revision", limit = 20
    static let revisionPattern = "^[a-f0-9]{32}$", changed = "workspace_transfers_changed", persisted = "workspace_transfers_persisted_invalid"
    static let missing = 404
}
enum UFitWorkspaceTransferFailure: LocalizedError {
    case document
    var errorDescription: String? { UFitWorkspaceTransfersCopy.invalid }
}
extension UFitAPIClient {
    func fetchWorkspaceTransfers(_ workspace: UFitWorkspaceReference, cursor: String? = nil, revision: String? = nil) async throws -> UFitWorkspaceTransferPage {
        guard UFitPaymentAllocationHTTP.validID(workspace.profileID), (cursor == nil) == (revision == nil) else { throw UFitWorkspaceTransferFailure.document }
        let path = workspace.isCreator ? UFitWorkspaceTransfersHTTP.creator : UFitWorkspaceTransfersHTTP.brands + workspace.profileID + UFitWorkspaceTransfersHTTP.history
        var query = [URLQueryItem(name: UFitWorkspaceTransfersHTTP.limitKey, value: String(UFitWorkspaceTransfersHTTP.limit))]
        if let cursor, let revision {
            query += [URLQueryItem(name: UFitWorkspaceTransfersHTTP.cursorKey, value: cursor), URLQueryItem(name: UFitWorkspaceTransfersHTTP.revisionKey, value: revision)]
        }
        let result: UFitWorkspaceTransferPage = try await send(UFitWorkspaceTransfersHTTP.get, path: path, query: query,
            requiresAuth: true, cachePolicy: .reloadIgnoringLocalCacheData)
        try result.validate(workspace: workspace); return result
    }
}
