import Foundation
import Observation

@MainActor @Observable
final class UFitApplicationsStore {
    private(set) var applications: UFitCurrentApplications?
    private(set) var isLoading = false
    private(set) var message: String?
    @ObservationIgnored private var generation = UUID()
    @ObservationIgnored private let client: UFitAPIClient
    @ObservationIgnored private let session: UFitSessionStore
    init(client: UFitAPIClient, session: UFitSessionStore) { self.client = client; self.session = session }
    func reset() { generation = UUID(); applications = nil; isLoading = false; message = nil }
    func load() async {
        guard !isLoading, let userID = session.user?.id else { return }
        let request = generation
        isLoading = true; message = nil
        defer { if generation == request { isLoading = false } }
        do {
            let result = try await client.fetchApplications()
            guard generation == request, session.user?.id == userID else { return }
            applications = result
            await session.reloadProfile()
        } catch { if generation == request && session.user?.id == userID { message = error.localizedDescription } }
    }
}
