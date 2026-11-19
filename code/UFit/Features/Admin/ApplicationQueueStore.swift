import Foundation
import Observation

@MainActor @Observable
final class UFitApplicationQueueStore {
    private(set) var items = [UFitApplicationQueueItem]()
    private(set) var filter: UFitApplicationQueueFilter = .pending
    private(set) var kind: UFitApplicationKind?
    private(set) var isLoading = false
    private(set) var hasLoaded = false
    private(set) var nextCursor: String?
    private(set) var message: String?
    @ObservationIgnored private let client: UFitAPIClient
    @ObservationIgnored private let session: UFitSessionStore
    @ObservationIgnored private var generation = UUID()
    init(client: UFitAPIClient, session: UFitSessionStore) { self.client = client; self.session = session }
    func reset() { generation = UUID(); items = []; filter = .pending; kind = nil; isLoading = false; hasLoaded = false; nextCursor = nil; message = nil }
    func select(filter: UFitApplicationQueueFilter) async { self.filter = filter; items = []; hasLoaded = false; nextCursor = nil; await load() }
    func select(kind: UFitApplicationKind?) async { self.kind = kind; items = []; hasLoaded = false; nextCursor = nil; await load() }
    func load(reset: Bool = true) async {
        guard session.user?.canAdminister == true, let userID = session.user?.id else { return }
        if !reset && (isLoading || nextCursor == nil) { return }
        if reset { generation = UUID() }
        let request = generation
        isLoading = true; message = nil
        defer { if generation == request { isLoading = false } }
        do {
            let page = try await client.fetchApplicationQueue(filter: filter, kind: kind, cursor: reset ? nil : nextCursor)
            guard generation == request, session.user?.id == userID else { return }
            if reset { items = page.items }
            else { for item in page.items { if let index = items.firstIndex(where: { $0.identity == item.identity }) { items[index] = item } else { items.append(item) } } }
            nextCursor = page.nextCursor; hasLoaded = true
        } catch { if generation == request && session.user?.id == userID { message = error.localizedDescription } }
    }
}
