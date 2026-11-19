import Foundation

enum UFitStylePreferencesHTTP {
    static let get = "GET", put = "PUT", root = "me/style-preferences/", changes = "/changes/"
    static let maximumStyles = 24, absentVersion = 0, firstVersion = 1, step = 1, maximumVersion = 2_147_483_647
    static let changed = "style_preferences_changed", requestChanged = "style_preferences_request_changed"
    static let invalid = "style_preferences_invalid", tagsInvalid = "style_preferences_tags_invalid", unavailable = "style_preferences_unavailable"
}
struct UFitStylePreferencesDocument: Decodable {
    let userId: String
    let version: Int
    let styleIds: [String]
    @UFitRequiredNullable var updatedAt: UFitTimestamp?
    func validate(userID: String) throws {
        guard userId == userID, canonicalUUID(userId),
              (UFitStylePreferencesHTTP.absentVersion...UFitStylePreferencesHTTP.maximumVersion).contains(version),
              (version == UFitStylePreferencesHTTP.absentVersion) == (updatedAt == nil),
              version != UFitStylePreferencesHTTP.absentVersion || styleIds.isEmpty else { throw UFitStylePreferencesFailure.document }
        try validateStyleIDs(styleIds)
    }
}
struct UFitStylePreferencesInput: Codable, Equatable {
    let requestId: String
    let expectedVersion: Int
    let styleIds: [String]
    func validate() throws {
        guard canonicalUUID(requestId), (UFitStylePreferencesHTTP.absentVersion..<UFitStylePreferencesHTTP.maximumVersion).contains(expectedVersion) else {
            throw UFitStylePreferencesFailure.document
        }
        try validateStyleIDs(styleIds)
    }
}
struct UFitStylePreferencesCommand: Codable, Equatable {
    let userID: String
    let input: UFitStylePreferencesInput
    func validate(userID expected: String) throws {
        guard userID == expected, canonicalUUID(userID) else { throw UFitStylePreferencesFailure.document }
        try input.validate()
    }
}
struct UFitStylePreferencesReceipt: Decodable, Equatable {
    let requestId: String
    let version: Int
    func validate(_ command: UFitStylePreferencesCommand) throws {
        guard requestId == command.input.requestId, version == command.input.expectedVersion + UFitStylePreferencesHTTP.step else {
            throw UFitStylePreferencesFailure.document
        }
    }
}
struct UFitStylePreferenceChangeStatus: Decodable {
    @UFitRequiredNullable var receipt: UFitStylePreferencesReceipt?
    let preferences: UFitStylePreferencesDocument
    func validate(_ command: UFitStylePreferencesCommand) throws {
        try preferences.validate(userID: command.userID)
        guard preferences.version >= command.input.expectedVersion else { throw UFitStylePreferencesFailure.document }
        if let receipt {
            try receipt.validate(command)
            guard preferences.version >= receipt.version,
                  preferences.version != receipt.version || preferences.styleIds == command.input.styleIds else { throw UFitStylePreferencesFailure.document }
        }
    }
}
enum UFitStylePreferencesFailure: LocalizedError {
    case document, storage
    var errorDescription: String? {
        switch self { case .document: UFitStylePreferencesCopy.loadFailed; case .storage: UFitStylePreferencesCopy.storageFailed }
    }
    static func code(_ error: Error) -> String? {
        if case .requestFailed(_, _, let code) = error as? UFitAPIError { return code }
        return nil
    }
    static func definitivelyRejected(_ error: Error) -> Bool {
        guard let code = code(error) else { return false }
        return [UFitStylePreferencesHTTP.changed, UFitStylePreferencesHTTP.requestChanged, UFitStylePreferencesHTTP.invalid,
                UFitStylePreferencesHTTP.tagsInvalid, UFitStylePreferencesHTTP.unavailable].contains(code)
    }
}
func validateStyleIDs(_ ids: [String]) throws {
    guard ids.count <= UFitStylePreferencesHTTP.maximumStyles, Set(ids).count == ids.count,
          ids == ids.sorted(), ids.allSatisfy(canonicalUUID) else { throw UFitStylePreferencesFailure.document }
}
private func canonicalUUID(_ raw: String) -> Bool { UUID(uuidString: raw)?.uuidString.lowercased() == raw }
extension UFitAPIClient {
    func fetchStylePreferences(userID: String) async throws -> UFitStylePreferencesDocument {
        let document: UFitStylePreferencesDocument = try await send(UFitStylePreferencesHTTP.get, path: UFitStylePreferencesHTTP.root + userID,
            requiresAuth: true, cachePolicy: .reloadIgnoringLocalCacheData)
        try document.validate(userID: userID)
        return document
    }
    func saveStylePreferences(_ command: UFitStylePreferencesCommand) async throws -> UFitStylePreferencesReceipt {
        try command.validate(userID: command.userID)
        let receipt: UFitStylePreferencesReceipt = try await send(UFitStylePreferencesHTTP.put,
            path: UFitStylePreferencesHTTP.root + command.userID, body: command.input, requiresAuth: true, publicOutfitsChange: false)
        try receipt.validate(command)
        return receipt
    }
    func fetchStylePreferenceChange(_ command: UFitStylePreferencesCommand) async throws -> UFitStylePreferenceChangeStatus {
        try command.validate(userID: command.userID)
        let status: UFitStylePreferenceChangeStatus = try await send(UFitStylePreferencesHTTP.get,
            path: UFitStylePreferencesHTTP.root + command.userID + UFitStylePreferencesHTTP.changes + command.input.requestId,
            requiresAuth: true, cachePolicy: .reloadIgnoringLocalCacheData)
        try status.validate(command)
        return status
    }
}
