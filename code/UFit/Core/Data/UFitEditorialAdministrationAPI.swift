import Foundation

enum UFitEditorialAdminHTTP {
    static let managed = "/managed", changes = "/changes/", status = "status", post = "POST", put = "PUT", patch = "PATCH"
    static let separator = ":", urlMaximum = 2_048, badRequest = 400, unauthorized = 401, forbidden = 403
}
extension UFitAPIClient {
    func fetchManagedEditorial(status: UFitEditorialStatus?, cursor: String? = nil) async throws -> UFitManagedEditorialPage {
        var query = [URLQueryItem(name: UFitEditorialHTTP.limit, value: String(UFitEditorialHTTP.pageSize))]
        if let status { query.append(.init(name: UFitEditorialAdminHTTP.status, value: status.rawValue)) }
        if let cursor { query.append(.init(name: UFitEditorialHTTP.cursor, value: cursor)) }
        let value: UFitManagedEditorialPage = try await send(UFitEditorialHTTP.get, path: UFitEditorialHTTP.root + UFitEditorialAdminHTTP.managed,
            query: query, requiresAuth: true, cachePolicy: .reloadIgnoringLocalCacheData)
        try value.validate(cursor: cursor, status: status); return value
    }
    func fetchManagedEditorial(id: String) async throws -> UFitManagedEditorialDetail {
        let value: UFitManagedEditorialDetail = try await send(UFitEditorialHTTP.get,
            path: UFitEditorialHTTP.root + UFitEditorialHTTP.slash + id + UFitEditorialAdminHTTP.managed, requiresAuth: true, cachePolicy: .reloadIgnoringLocalCacheData)
        try value.validate(); guard value.collection.id == id else { throw UFitEditorialFailure.contract }; return value
    }
    func fetchEditorialChange(_ command: UFitEditorialCommand) async throws -> UFitEditorialChange {
        let value: UFitEditorialChange = try await send(UFitEditorialHTTP.get, path: UFitEditorialHTTP.root + UFitEditorialAdminHTTP.changes + command.requestID,
            requiresAuth: true, cachePolicy: .reloadIgnoringLocalCacheData)
        try value.validate(command); return value
    }
    func sendEditorialCommand(_ command: UFitEditorialCommand) async throws -> UFitEditorialReceipt {
        try command.validate(actorID: command.actorID)
        let value: UFitEditorialReceipt
        if let fields = command.fields {
            value = try await send(command.kind == .create ? UFitEditorialAdminHTTP.post : UFitEditorialAdminHTTP.put,
                path: UFitEditorialHTTP.root + (command.collectionID.map { UFitEditorialHTTP.slash + $0 } ?? String()),
                body: EditorialWrite(requestId: command.requestID, expectedVersion: command.expectedVersion, fields: fields), requiresAuth: true, publicOutfitsChange: false)
        } else {
            guard let id = command.collectionID else { throw UFitEditorialFailure.contract }
            value = try await send(UFitEditorialAdminHTTP.patch, path: UFitEditorialHTTP.root + UFitEditorialHTTP.slash + id + UFitEditorialHTTP.slash + command.kind.rawValue,
                body: EditorialTransition(requestId: command.requestID, expectedVersion: command.expectedVersion), requiresAuth: true, publicOutfitsChange: false)
        }
        try value.validate(command); return value
    }
}
private struct EditorialWrite: Encodable { let requestId: String; let expectedVersion: Int; let fields: UFitEditorialFields }
private struct EditorialTransition: Encodable { let requestId: String; let expectedVersion: Int }
