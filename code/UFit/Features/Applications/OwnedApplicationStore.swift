import Foundation
import Observation

@MainActor @Observable
final class UFitOwnedApplicationStore {
    let id: String
    let kind: UFitApplicationKind
    private(set) var document: UFitApplicationDocument?
    private(set) var isLoading = false
    private(set) var message: String?
    @ObservationIgnored private let session: UFitSessionStore
    @ObservationIgnored private let userID: String
    init(id: String, kind: UFitApplicationKind, session: UFitSessionStore) throws {
        guard UUID(uuidString: id) != nil, let userID = session.user?.id else { throw UFitNotificationError.document }
        self.id = id; self.kind = kind; self.session = session; self.userID = userID
    }
    func load() async {
        guard !isLoading, session.user?.id == userID else { return }
        isLoading = true; message = nil
        defer { isLoading = false }
        do {
            let result = try await session.api.fetchOwnedApplication(kind: kind, id: id)
            guard session.user?.id == userID else { return }
            guard result.metadata.userId == userID else { throw UFitNotificationError.document }
            document = result
        } catch {
            guard session.user?.id == userID else { return }
            if case .requestFailed(let status, _, _) = error as? UFitAPIError, Contract.denied.contains(status) { document = nil }
            message = error.localizedDescription
        }
    }
    private enum Contract { static let denied: Set<Int> = [401, 403, 404] }
}
