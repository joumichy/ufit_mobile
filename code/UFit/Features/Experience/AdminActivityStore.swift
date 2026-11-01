import Foundation
import Observation

@MainActor @Observable
final class UFitAdminActivityStore {
    private(set) var activity: UFitAdminActivity?
    private(set) var isLoading = false
    private(set) var message: String?
    @ObservationIgnored private let session: UFitSessionStore
    @ObservationIgnored private var generation = UUID()
    init(session: UFitSessionStore) { self.session = session }
    func reset() { cancelLoading(); activity = nil; message = nil }
    func cancelLoading() { generation = UUID(); isLoading = false }
    func load() async {
        guard !isLoading, let userID = session.user?.id, session.user?.canAdminister == true else { return }
        let request = generation
        isLoading = true; activity = nil; message = nil
        defer { if generation == request { isLoading = false } }
        do {
            let value = try await session.api.fetchAdminActivity()
            guard generation == request, session.user?.id == userID else { return }
            activity = value
        } catch { if generation == request && session.user?.id == userID { message = error.localizedDescription } }
    }
}
