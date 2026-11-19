import Foundation

private enum ProfileAdministrationHTTP {
    static let root = "admin/users/", profiles = "/profiles/", separator = "/", changes = "/changes", status = "/status"
    static let get = "GET", post = "POST", limit = "limit", cursor = "cursor"
    static func path(userID: String, kind: UFitAdministeredProfileKind, profileID: String? = nil) throws -> String {
        guard UFitUserAdministrationContract.identifier(userID), profileID == nil || UFitUserAdministrationContract.identifier(profileID!) else { throw UFitUserAdministrationFailure.input }
        let base = root + userID + profiles + kind.rawValue
        return profileID.map { base + separator + $0 } ?? base
    }
    static func page(_ cursor: String?) throws -> [URLQueryItem] {
        guard cursor == nil || UFitUserAdministrationContract.identifier(cursor!) else { throw UFitUserAdministrationFailure.input }
        var query = [URLQueryItem(name: limit, value: String(UFitUserAdministrationContract.pageLimit))]
        if let cursor { query.append(.init(name: Self.cursor, value: cursor)) }
        return query
    }
}
extension UFitAPIClient {
    func fetchAdministeredProfiles(userID: String, kind: UFitAdministeredProfileKind, cursor: String? = nil) async throws -> UFitUserAdministrationPageDTO<UFitAdministeredProfileDTO> {
        let result: UFitUserAdministrationPageDTO<UFitAdministeredProfileDTO> = try await send(ProfileAdministrationHTTP.get,
            path: ProfileAdministrationHTTP.path(userID: userID, kind: kind), query: ProfileAdministrationHTTP.page(cursor), requiresAuth: true)
        try result.validate(cursor: cursor)
        guard result.items.allSatisfy({ $0.kind == kind && (cursor == nil || $0.id > cursor!) }),
              zip(result.items, result.items.dropFirst()).allSatisfy({ $0.id < $1.id }) else { throw UFitUserAdministrationFailure.page }
        return result
    }
    func fetchAdministeredProfile(userID: String, kind: UFitAdministeredProfileKind, id: String) async throws -> UFitAdministeredProfileDTO {
        let result: UFitAdministeredProfileDTO = try await send(ProfileAdministrationHTTP.get,
            path: ProfileAdministrationHTTP.path(userID: userID, kind: kind, profileID: id), requiresAuth: true)
        guard result.id == id, result.kind == kind else { throw UFitUserAdministrationFailure.document }
        return result
    }
    func fetchProfileStatusHistory(userID: String, kind: UFitAdministeredProfileKind, id: String, cursor: String? = nil) async throws -> UFitUserAdministrationPageDTO<UFitProfileStatusChangeDTO> {
        let result: UFitUserAdministrationPageDTO<UFitProfileStatusChangeDTO> = try await send(ProfileAdministrationHTTP.get,
            path: ProfileAdministrationHTTP.path(userID: userID, kind: kind, profileID: id) + ProfileAdministrationHTTP.changes,
            query: ProfileAdministrationHTTP.page(cursor), requiresAuth: true)
        try result.validate(cursor: cursor)
        guard result.items.allSatisfy({ $0.profileId == id && $0.kind == kind }),
              zip(result.items, result.items.dropFirst()).allSatisfy({ $0.version > $1.version }) else { throw UFitUserAdministrationFailure.page }
        return result
    }
    func changeProfileStatus(userID: String, current: UFitAdministeredProfileDTO, status: UFitProfileStatus, reason: String) async throws -> UFitAdministeredProfileDTO {
        guard current.allows(status), current.version < UFitUserAdministrationContract.maximumVersion, UFitUserAdministrationContract.reason(reason) else { throw UFitUserAdministrationFailure.input }
        let result: UFitAdministeredProfileDTO = try await send(ProfileAdministrationHTTP.post,
            path: ProfileAdministrationHTTP.path(userID: userID, kind: current.kind, profileID: current.id) + ProfileAdministrationHTTP.status,
            body: ProfileStatusCommand(expectedVersion: current.version, status: status, reason: reason), requiresAuth: true, publicOutfitsChange: true)
        guard result.id == current.id, result.kind == current.kind, result.status == status,
              result.version == current.version + UFitUserAdministrationContract.versionStep else { throw UFitUserAdministrationFailure.document }
        return result
    }
}
private struct ProfileStatusCommand: Encodable { let expectedVersion: Int; let status: UFitProfileStatus; let reason: String }
