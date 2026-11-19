import Foundation

private enum NotificationHTTP { static let get = "GET", root = "notifications", separator = "/" }
extension UFitAPIClient {
    func fetchNotification(id: String) async throws -> UFitNotificationDetail {
        guard let identifier = UUID(uuidString: id), identifier.uuidString.lowercased() == id else { throw UFitNotificationError.document }
        let result: UFitNotificationDetail = try await send(NotificationHTTP.get, path: NotificationHTTP.root + NotificationHTTP.separator + id, requiresAuth: true, cachePolicy: .reloadIgnoringLocalCacheData)
        guard result.id == id, !result.subject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !result.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw UFitNotificationError.document }
        return result
    }
}
