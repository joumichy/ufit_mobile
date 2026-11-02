import Foundation

enum UFitPushEnvironment: String, Codable { case development, production }
enum UFitInstallationHTTP {
    static let get = "GET", put = "PUT", delete = "DELETE", path = "notifications/installations/"
    static let accounts = "/accounts/", associations = "/associations/", proofHeader = "x-ufit-installation-key"
    static let absentVersion = 0, maximumVersion = 2_147_483_647, step = 1
    static let conflictStatus = 409, closedCode = "notification_association_closed"
    static func identifier(_ value: String) -> Bool { UUID(uuidString: value)?.uuidString.lowercased() == value }
}
enum UFitInstallationFailure: LocalizedError {
    case document, storage, configuration
    var errorDescription: String? { UFitNotificationDeviceCopy.unavailable }
}
struct UFitInstallationDocument: Decodable {
    enum State: String, Decodable { case unregistered, registered, detached, invalidated }
    let installationId: String
    let version: Int
    let state: State
    @UFitRequiredNullable var associationId: String?
    @UFitRequiredNullable var registrationId: String?
    @UFitRequiredNullable var environment: UFitPushEnvironment?
    @UFitRequiredNullable var registeredAt: UFitTimestamp?
    let isCurrentAccount: Bool
    @UFitRequiredNullable var updatedAt: UFitTimestamp?
    func validate(id: String) throws {
        let absent = version == UFitInstallationHTTP.absentVersion
        let bound = state == .registered || state == .invalidated
        guard installationId == id, UFitInstallationHTTP.identifier(id),
              (UFitInstallationHTTP.absentVersion...UFitInstallationHTTP.maximumVersion).contains(version),
              absent == (state == .unregistered), absent == (updatedAt == nil),
              (bound && associationId != nil && registrationId != nil && environment != nil && registeredAt != nil) ||
                (!bound && associationId == nil && registrationId == nil && environment == nil && registeredAt == nil && !isCurrentAccount),
              associationId.map(UFitInstallationHTTP.identifier) ?? true,
              registrationId.map(UFitInstallationHTTP.identifier) ?? true else { throw UFitInstallationFailure.document }
    }
    func confirms(_ operation: UFitInstallationOperation, association: String) -> Bool {
        state == .registered && isCurrentAccount && associationId == association && registrationId == operation.id && environment == operation.environment
    }
}
private struct InstallationRegistrationInput: Encodable {
    let expectedVersion: Int, associationId: String, registrationId: String, deviceToken: String
    let environment: UFitPushEnvironment
}
private struct InstallationDetachInput: Encodable {}
private struct InstallationDetachDocument: Decodable { let installationId: String, associationId: String, detached: Bool }
extension UFitAPIClient {
    func installation(_ identity: UFitInstallationIdentity) async throws -> UFitInstallationDocument {
        let value: UFitInstallationDocument = try await send(UFitInstallationHTTP.get, path: UFitInstallationHTTP.path + identity.id,
            requiresAuth: true, cachePolicy: .reloadIgnoringLocalCacheData, headers: [UFitInstallationHTTP.proofHeader: identity.proof])
        try value.validate(id: identity.id); return value
    }
    func registerInstallation(_ identity: UFitInstallationIdentity, binding: UFitInstallationBinding,
                              operation: UFitInstallationOperation, token: String) async throws -> UFitInstallationDocument {
        try identity.validate()
        guard UFitInstallationHTTP.identifier(binding.userID), UFitInstallationHTTP.identifier(binding.id),
              operation.tokenDigest == UFitInstallationIdentity.digest(token) else { throw UFitInstallationFailure.document }
        let body = InstallationRegistrationInput(expectedVersion: operation.version, associationId: binding.id,
            registrationId: operation.id, deviceToken: token, environment: operation.environment)
        let value: UFitInstallationDocument = try await send(UFitInstallationHTTP.put,
            path: UFitInstallationHTTP.path + identity.id + UFitInstallationHTTP.accounts + binding.userID,
            body: body, requiresAuth: true, headers: [UFitInstallationHTTP.proofHeader: identity.proof])
        try value.validate(id: identity.id)
        guard value.confirms(operation, association: binding.id), value.version == operation.version + UFitInstallationHTTP.step else {
            throw UFitInstallationFailure.document
        }
        return value
    }
    func detachInstallation(_ identity: UFitInstallationIdentity, association: String) async throws {
        try identity.validate(); guard UFitInstallationHTTP.identifier(association) else { throw UFitInstallationFailure.document }
        let value: InstallationDetachDocument = try await send(UFitInstallationHTTP.delete,
            path: UFitInstallationHTTP.path + identity.id + UFitInstallationHTTP.associations + association,
            body: InstallationDetachInput(), headers: [UFitInstallationHTTP.proofHeader: identity.proof])
        guard value.installationId == identity.id, value.associationId == association, value.detached else { throw UFitInstallationFailure.document }
    }
}
