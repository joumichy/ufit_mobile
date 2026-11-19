import Foundation

private enum NotificationPreferencesHTTP {
    static let get = "GET", put = "PUT", path = "notifications/preferences/"
    static let absentVersion = 0, firstVersion = 1, step = 1, maximumVersion = 2_147_483_647
    static let defaults = UFitNotificationChoices(emailEnabled: true, pushEnabled: true)
}

struct UFitNotificationPreferencesDTO: Decodable {
    let userId: String
    let version: Int
    let emailEnabled: Bool
    let pushEnabled: Bool
    @UFitRequiredNullable var updatedAt: UFitTimestamp?
    var choices: UFitNotificationChoices { .init(emailEnabled: emailEnabled, pushEnabled: pushEnabled) }
    var allowsEditing: Bool { version < NotificationPreferencesHTTP.maximumVersion }
    func validate(userID: String) throws {
        guard userId == userID, UUID(uuidString: userId)?.uuidString.lowercased() == userId,
              (NotificationPreferencesHTTP.absentVersion...NotificationPreferencesHTTP.maximumVersion).contains(version),
              (version == NotificationPreferencesHTTP.absentVersion) == (updatedAt == nil),
              version != NotificationPreferencesHTTP.absentVersion || choices == NotificationPreferencesHTTP.defaults else {
            throw UFitNotificationPreferencesFailure.document
        }
    }
    func confirms(_ submitted: UFitNotificationChoices, after previous: Self) -> Bool {
        choices == submitted && (version == previous.version + NotificationPreferencesHTTP.step ||
            version == previous.version && choices == previous.choices && version >= NotificationPreferencesHTTP.firstVersion)
    }
}

enum UFitNotificationPreferencesFailure: LocalizedError {
    case document
    var errorDescription: String? { UFitNotificationPreferencesCopy.loadFailed }
    static let conflictStatus = 409
    static let conflictCode = "notification_preferences_changed"
    static let serverFailureStatus = 500
    static func conflict(_ error: Error) -> Bool {
        guard case .requestFailed(let status, _, let code) = error as? UFitAPIError else { return false }
        return status == conflictStatus && code == conflictCode
    }
    static func mayHaveSaved(_ error: Error) -> Bool {
        if case .requestFailed(let status, _, _) = error as? UFitAPIError { return status >= serverFailureStatus }
        return true
    }
}

extension UFitAPIClient {
    func fetchNotificationPreferences(userID: String) async throws -> UFitNotificationPreferencesDTO {
        let result: UFitNotificationPreferencesDTO = try await send(NotificationPreferencesHTTP.get,
            path: NotificationPreferencesHTTP.path + userID, requiresAuth: true, cachePolicy: .reloadIgnoringLocalCacheData)
        try result.validate(userID: userID)
        return result
    }
    func saveNotificationPreferences(_ current: UFitNotificationPreferencesDTO, choices: UFitNotificationChoices) async throws -> UFitNotificationPreferencesDTO {
        try current.validate(userID: current.userId)
        guard current.allowsEditing else { throw UFitNotificationPreferencesFailure.document }
        let result: UFitNotificationPreferencesDTO = try await send(NotificationPreferencesHTTP.put,
            path: NotificationPreferencesHTTP.path + current.userId,
            body: NotificationPreferencesInput(expectedVersion: current.version, emailEnabled: choices.emailEnabled, pushEnabled: choices.pushEnabled), requiresAuth: true, publicOutfitsChange: false)
        try result.validate(userID: current.userId)
        guard result.confirms(choices, after: current) else { throw UFitNotificationPreferencesFailure.document }
        return result
    }
}

private struct NotificationPreferencesInput: Encodable {
    let expectedVersion: Int
    let emailEnabled: Bool
    let pushEnabled: Bool
}
