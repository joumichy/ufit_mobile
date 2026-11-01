import Foundation
import Observation

@MainActor @Observable
final class UFitReturnsStore {
    let scope: UFitReturnScope
    let context: String
    @ObservationIgnored let session: UFitSessionStore
    @ObservationIgnored private let userID: String
    @ObservationIgnored private var generation = UUID()
    private(set) var returns: [UFitReturnSummaryDTO] = []
    private(set) var filter: UFitReturnStatus?
    private(set) var isLoading = false
    private(set) var hasLoaded = false
    private(set) var nextCursor: String?
    private(set) var message: String?
    init(scope: UFitReturnScope, context: String, session: UFitSessionStore) throws {
        guard let userID = session.user?.id else { throw UFitAPIError.authenticationRequired }
        _ = try scope.path
        self.scope = scope; self.context = context; self.session = session; self.userID = userID
    }
    var isCurrentAccount: Bool { session.user?.id == userID }
    var summaries: [UFitReturnSummaryPresentation] { returns.map(\.presentation) }
    func select(_ status: UFitReturnStatus?) async {
        guard isCurrentAccount, status != filter else { return }
        generation = UUID(); filter = status; returns = []; nextCursor = nil; hasLoaded = false; isLoading = false; message = nil
        await load()
    }
    func load(reset: Bool = true) async {
        guard !isLoading, isCurrentAccount, reset || nextCursor != nil else { return }
        let request = generation, cursor = reset ? nil : nextCursor
        isLoading = true; message = nil
        defer { if generation == request { isLoading = false } }
        do {
            let page = try await session.api.fetchReturns(scope: scope, status: filter, cursor: cursor)
            guard generation == request, isCurrentAccount else { return }
            if reset { returns = page.items }
            else {
                guard Set(page.items.map(\.id)).isDisjoint(with: Set(returns.map(\.id))) else { throw UFitReturnContractError.page }
                returns.append(contentsOf: page.items)
            }
            nextCursor = page.nextCursor; hasLoaded = true
        } catch {
            guard generation == request, isCurrentAccount else { return }
            if (error as? UFitAPIError)?.losesReturnAccess == true { loseAccess(error) }
            else { message = error.localizedDescription }
        }
    }
    func receive(_ summary: UFitReturnSummaryDTO) {
        guard isCurrentAccount, scope.contains(orderID: summary.orderId, brandID: summary.brandId) else { return }
        let visible = filter == nil || filter == summary.status
        if let index = returns.firstIndex(where: { $0.id == summary.id }) {
            if visible { returns[index] = summary } else { returns.remove(at: index) }
        } else if visible { returns.insert(summary, at: .zero) }
    }
    func reportOpeningFailure(_ error: Error) { guard isCurrentAccount else { return }; message = error.localizedDescription }
    func loseAccess(_ error: Error) {
        guard isCurrentAccount else { return }
        generation = UUID(); returns = []; nextCursor = nil; hasLoaded = false; isLoading = false; message = error.localizedDescription
    }
}
