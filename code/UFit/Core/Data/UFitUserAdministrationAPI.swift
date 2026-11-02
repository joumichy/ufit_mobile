import Foundation

private enum UserAdministrationHTTP {
    static let get = "GET"
    static let post = "POST"
    static let root = "admin/users"
    static let separator = "/"
    static let history = "/access-history"
    static let statusChange = "/status"
    static let adminAccess = "/admin-access"
    static let limit = "limit"
    static let cursor = "cursor"
    static let search = "search"
    static let status = "status"
    static let role = "role"
    static func page(cursor: String?) throws -> [URLQueryItem] {
        guard cursor == nil || UFitUserAdministrationContract.identifier(cursor!) else { throw UFitUserAdministrationFailure.input }
        var query = [URLQueryItem(name: limit, value: String(UFitUserAdministrationContract.pageLimit))]
        if let cursor { query.append(URLQueryItem(name: Self.cursor, value: cursor)) }
        return query
    }
    static func user(_ id: String) throws -> String {
        guard UFitUserAdministrationContract.identifier(id) else { throw UFitUserAdministrationFailure.input }
        return root + separator + id
    }
}

extension UFitAPIClient {
    func fetchAdministeredUsers(cursor: String? = nil, search: String = String(), status: UFitAccountStatus? = nil, role: UFitUserRole? = nil) async throws -> UFitUserAdministrationPageDTO<UFitAdministeredUserDTO> {
        let search = UFitServerTextInput.trimmed(search)
        guard search.utf16.count <= UFitUserAdministrationContract.searchLimit else { throw UFitUserAdministrationFailure.input }
        var query = try UserAdministrationHTTP.page(cursor: cursor)
        if !search.isEmpty { query.append(URLQueryItem(name: UserAdministrationHTTP.search, value: search)) }
        if let status { query.append(URLQueryItem(name: UserAdministrationHTTP.status, value: status.rawValue)) }
        if let role { query.append(URLQueryItem(name: UserAdministrationHTTP.role, value: role.rawValue)) }
        let result: UFitUserAdministrationPageDTO<UFitAdministeredUserDTO> = try await send(UserAdministrationHTTP.get, path: UserAdministrationHTTP.root, query: query, requiresAuth: true)
        try result.validate(cursor: cursor)
        guard result.items.allSatisfy({ (status == nil || $0.status == status) && (role == nil || $0.roles.contains(role!)) && (cursor == nil || $0.id > cursor!) }),
              zip(result.items, result.items.dropFirst()).allSatisfy({ $0.id < $1.id }) else { throw UFitUserAdministrationFailure.page }
        return result
    }
    func fetchAdministeredUser(id: String) async throws -> UFitAdministeredUserDTO {
        let result: UFitAdministeredUserDTO = try await send(UserAdministrationHTTP.get, path: UserAdministrationHTTP.user(id), requiresAuth: true)
        guard result.id == id else { throw UFitUserAdministrationFailure.document }
        return result
    }
    func fetchUserAccessHistory(userID: String, cursor: String? = nil) async throws -> UFitUserAdministrationPageDTO<UFitUserAccessChangeDTO> {
        let result: UFitUserAdministrationPageDTO<UFitUserAccessChangeDTO> = try await send(UserAdministrationHTTP.get,
            path: UserAdministrationHTTP.user(userID) + UserAdministrationHTTP.history, query: UserAdministrationHTTP.page(cursor: cursor), requiresAuth: true)
        try result.validate(cursor: cursor)
        guard result.items.allSatisfy({ $0.userId == userID }), zip(result.items, result.items.dropFirst()).allSatisfy({ $0.version > $1.version }) else { throw UFitUserAdministrationFailure.page }
        return result
    }
    func changeUserStatus(_ current: UFitAdministeredUserDTO, status: UFitAccountStatus, reason: String) async throws -> UFitAdministeredUserDTO {
        guard current.version < UFitUserAdministrationContract.maximumVersion, UFitUserAdministrationContract.reason(reason),
              (status == .active && current.actions.activate) || (status == .suspended && current.actions.suspend) else { throw UFitUserAdministrationFailure.input }
        let result: UFitAdministeredUserDTO = try await send(UserAdministrationHTTP.post, path: UserAdministrationHTTP.user(current.id) + UserAdministrationHTTP.statusChange,
            body: UserStatusChange(expectedVersion: current.version, status: status, reason: reason), requiresAuth: true)
        guard result.id == current.id, result.version == current.version + UFitUserAdministrationContract.versionStep,
              result.status == status, result.roleCodes == current.roleCodes else { throw UFitUserAdministrationFailure.document }
        return result
    }
    func changeUserAdminAccess(_ current: UFitAdministeredUserDTO, enabled: Bool, reason: String) async throws -> UFitAdministeredUserDTO {
        guard current.version < UFitUserAdministrationContract.maximumVersion, UFitUserAdministrationContract.reason(reason),
              enabled ? current.actions.grantAdmin : current.actions.revokeAdmin else { throw UFitUserAdministrationFailure.input }
        let result: UFitAdministeredUserDTO = try await send(UserAdministrationHTTP.post, path: UserAdministrationHTTP.user(current.id) + UserAdministrationHTTP.adminAccess,
            body: UserAdminAccessChange(expectedVersion: current.version, enabled: enabled, reason: reason), requiresAuth: true)
        var roles = current.roleCodes
        if enabled { roles.insert(UFitUserRole.admin.rawValue) } else { roles.remove(UFitUserRole.admin.rawValue) }
        guard result.id == current.id, result.version == current.version + UFitUserAdministrationContract.versionStep,
              result.status == current.status, result.roleCodes == roles else { throw UFitUserAdministrationFailure.document }
        return result
    }
}

private struct UserStatusChange: Encodable { let expectedVersion: Int; let status: UFitAccountStatus; let reason: String }
private struct UserAdminAccessChange: Encodable { let expectedVersion: Int; let enabled: Bool; let reason: String }
