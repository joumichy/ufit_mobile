import Foundation
import Observation

@MainActor @Observable
final class UFitWorkspacesStore {
    private(set) var spaces = [UFitWorkspaceReference]()
    private(set) var hasLoaded = false
    private(set) var isLoading = false
    private(set) var busyIDs = Set<String>()
    private(set) var message: String?
    @ObservationIgnored private var generation = UUID()
    @ObservationIgnored private var openingID: String?
    @ObservationIgnored private let client: UFitAPIClient
    @ObservationIgnored private let session: UFitSessionStore
    init(client: UFitAPIClient, session: UFitSessionStore) { self.client = client; self.session = session }
    func reset() { generation = UUID(); spaces = []; hasLoaded = false; isLoading = false; busyIDs = []; message = nil; openingID = nil }
    func cancelOpening() { openingID = nil }
    func reportOpeningFailure(_ error: Error, space: UFitWorkspaceReference) {
        guard spaces.contains(space), session.user != nil else { return }
        message = error.localizedDescription
    }
    func load() async {
        guard !isLoading, let userID = session.user?.id else { return }
        let request = generation
        isLoading = true; message = nil
        defer { if generation == request { isLoading = false } }
        do {
            let memberships = try await client.fetchAllWorkspaceMemberships()
            guard generation == request, session.user?.id == userID else { return }
            spaces = memberships.creator.map { [.creator($0)] } ?? []
            spaces.append(contentsOf: memberships.brands.map { .brand($0) })
            hasLoaded = true
        } catch { if generation == request && session.user?.id == userID { message = error.localizedDescription } }
    }
    func open(_ space: UFitWorkspaceReference) async -> UFitManagedProfileStore? {
        guard spaces.contains(space), !busyIDs.contains(space.id), let userID = session.user?.id else { return nil }
        let request = generation
        openingID = space.id; busyIDs.insert(space.id); message = nil
        defer { if generation == request { busyIDs.remove(space.id) } }
        do {
            let document = try await client.fetchManagedProfile(space, userID: userID)
            guard generation == request, session.user?.id == userID, openingID == space.id else { return nil }
            return UFitManagedProfileStore(document: document, client: client, session: session)
        } catch { if generation == request && session.user?.id == userID && openingID == space.id { message = error.localizedDescription }; return nil }
    }
}
