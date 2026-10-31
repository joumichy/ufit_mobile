import Foundation
import Observation

@MainActor @Observable
final class UFitOrdersStore {
    private(set) var orders = [UFitOrderDTO]()
    private(set) var isLoading = false
    private(set) var nextCursor: String?
    var message: String?
    @ObservationIgnored private let client: UFitAPIClient
    @ObservationIgnored private let session: UFitSessionStore
    @ObservationIgnored private var generation = UUID()
    init(client: UFitAPIClient, session: UFitSessionStore) { self.client = client; self.session = session }
    var summaries: [UFitOrderSummary] { orders.map(UFitOrderPresentationAdapter.summary) }
    func reset() { generation = UUID(); isLoading = false; orders = []; nextCursor = nil; message = nil }
    func receive(_ order: UFitOrderDTO) {
        if let index = orders.firstIndex(where: { $0.id == order.id }) { orders[index] = order }
        else { orders.append(order) }
        orders.sort { $0.createdAt == $1.createdAt ? $0.id > $1.id : $0.createdAt > $1.createdAt }
    }
    func load(reset: Bool = true) async {
        guard !isLoading, let userID = session.user?.id else { return }
        if !reset && nextCursor == nil { return }
        let requestGeneration = generation
        isLoading = true; message = nil
        defer { if generation == requestGeneration { isLoading = false } }
        do {
            let page = try await client.fetchOrders(cursor: reset ? nil : nextCursor)
            guard session.user?.id == userID, generation == requestGeneration else { return }
            if reset { orders = page.items }
            else { for order in page.items { receive(order) } }
            nextCursor = page.nextCursor
        } catch { if session.user?.id == userID && generation == requestGeneration { message = error.localizedDescription } }
    }
}
