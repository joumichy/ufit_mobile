import Foundation
import Observation

@MainActor @Observable
final class UFitBrandOrdersStore {
    let brandID: String
    let brandName: String
    @ObservationIgnored let session: UFitSessionStore
    @ObservationIgnored private let userID: String
    @ObservationIgnored private var generation = UUID()
    @ObservationIgnored private var retryMore = false
    private(set) var orders: [UFitBrandOrderSummaryDTO] = []
    private(set) var filter: UFitOrderLifecycle?
    private(set) var isLoading = false
    private(set) var hasLoaded = false
    private(set) var nextCursor: String?
    private(set) var message: String?
    init(space: UFitWorkspaceReference, session: UFitSessionStore) throws {
        guard !space.isCreator, space.status == .active || space.status == .paused, UUID(uuidString: space.profileID) != nil,
              let userID = session.user?.id else { throw UFitBrandOrderContractError.document }
        brandID = space.profileID.lowercased(); brandName = space.name; self.session = session; self.userID = userID
    }
    var isCurrentAccount: Bool { session.user?.id == userID }
    var summaries: [UFitOrderSummary] { orders.map(\.presentation) }
    func select(_ status: UFitOrderLifecycle?) async {
        guard isCurrentAccount, status == nil || UFitBrandOrderInput.statuses.contains(where: { $0 == status }), status != filter else { return }
        generation = UUID(); filter = status; orders = []; nextCursor = nil; hasLoaded = false; isLoading = false; message = nil
        await load()
    }
    func retry() async { await load(reset: !retryMore) }
    func load(reset: Bool = true) async {
        guard !isLoading, isCurrentAccount, reset || nextCursor != nil else { return }
        let request = generation, cursor = reset ? nil : nextCursor
        isLoading = true; message = nil; retryMore = !reset
        defer { if generation == request { isLoading = false } }
        do {
            let page = try await session.api.fetchBrandOrders(brandID: brandID, status: filter, cursor: cursor)
            guard generation == request, isCurrentAccount else { return }
            if reset { orders = page.items }
            else {
                guard Set(page.items.map(\.id)).isDisjoint(with: Set(orders.map(\.id))) else { throw UFitBrandOrderContractError.page }
                orders.append(contentsOf: page.items)
            }
            nextCursor = page.nextCursor; hasLoaded = true
        } catch {
            guard generation == request, isCurrentAccount else { return }
            if (error as? UFitAPIError)?.losesBrandOrderAccess == true { loseAccess(error) }
            else { message = error.localizedDescription }
        }
    }
    func receive(_ summary: UFitBrandOrderSummaryDTO) {
        guard isCurrentAccount, summary.brandId == brandID, let index = orders.firstIndex(where: { $0.id == summary.id }) else { return }
        if filter == nil || filter == summary.status { orders[index] = summary }
        else { orders.remove(at: index) }
    }
    func reportOpeningFailure(_ error: Error) {
        guard isCurrentAccount else { return }; message = error.localizedDescription
    }
    func loseAccess(_ error: Error) {
        guard isCurrentAccount else { return }
        generation = UUID(); orders = []; nextCursor = nil; hasLoaded = false; isLoading = false; retryMore = false; message = error.localizedDescription
    }
}
