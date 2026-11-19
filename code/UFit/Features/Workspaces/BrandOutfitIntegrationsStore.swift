import Foundation
import Observation

@MainActor @Observable
final class UFitBrandOutfitIntegrationsStore {
    enum Operation { case idle, loading, refreshing, more }
    let workspace: UFitWorkspaceReference
    private(set) var operation = Operation.idle
    private(set) var hasLoaded = false
    private(set) var accessRevoked = false
    private(set) var failureAtEnd = false
    var visibleEntryID: String?
    private var failure: String?
    private var cached = [UFitBrandOutfitIntegration]()
    private var nextCursor: String?
    private var consumedCursors = Set<String>()
    @ObservationIgnored private let session: UFitSessionStore
    @ObservationIgnored private let accountID: String?
    @ObservationIgnored private var generation = UUID()
    @ObservationIgnored private var retryMore = false
    private enum Copy {
        static let access = String(localized: "Votre accès à cette marque a changé. Revenez aux espaces et actualisez vos accès.")
        static let changed = String(localized: "Les tenues ont changé. Actualisez la page pour retrouver les pièces concernées.")
        static let moreUnavailable = String(localized: "Impossible de charger les tenues suivantes.")
    }
    private enum Response { static let forbidden = 403; static let missing = 404; static let changed = 409; static let unavailable = 503 }
    init(workspace: UFitWorkspaceReference, session: UFitSessionStore) {
        self.workspace = workspace; self.session = session; accountID = session.user?.id
    }
    var isCurrentAccount: Bool { accountID != nil && accountID == session.user?.id }
    var canRead: Bool { isCurrentAccount && session.user?.isBrandMember == true && !workspace.isCreator && workspace.status.canChangeVisibility }
    var entries: [UFitBrandOutfitIntegration] { canRead && !accessRevoked ? cached : [] }
    var message: String? { canRead && !accessRevoked ? failure : Copy.access }
    var hasMore: Bool { canRead && !accessRevoked && nextCursor != nil }
    var isBusy: Bool { operation != .idle }
    var retriesNextPage: Bool { failureAtEnd && retryMore }
    func load(more: Bool = false) async {
        guard canRead, !accessRevoked, !isBusy, !more || nextCursor != nil else { return }
        let request = generation, cursor = more ? nextCursor : nil
        operation = more ? .more : (hasLoaded ? .refreshing : .loading)
        retryMore = more; failureAtEnd = false; failure = nil
        defer { if generation == request { operation = .idle } }
        do {
            let page = try await session.api.fetchBrandOutfitIntegrations(brandID: workspace.profileID, cursor: cursor)
            guard generation == request, canRead, !Task.isCancelled else { return }
            if more {
                guard let cursor, !consumedCursors.contains(cursor), Set(cached.map(\.id)).isDisjoint(with: page.items.map(\.id)) else {
                    throw UFitBrandOutfitIntegrationFailure.invalid
                }
                cached.append(contentsOf: page.items); consumedCursors.insert(cursor)
            } else {
                cached = page.items; consumedCursors = []
                if let visibleEntryID, !cached.contains(where: { $0.id == visibleEntryID }) { self.visibleEntryID = nil }
            }
            nextCursor = page.nextCursor; hasLoaded = true
        } catch {
            guard generation == request, canRead, !Task.isCancelled else { return }
            if case UFitAPIError.requestFailed(let status, _, _) = error {
                if status == Response.forbidden || status == Response.missing {
                    cached = []; nextCursor = nil; consumedCursors = []; visibleEntryID = nil; hasLoaded = false; accessRevoked = true
                    return
                }
                if status == Response.changed { retryMore = false; failure = Copy.changed }
                if status == Response.unavailable && more { failure = Copy.moreUnavailable }
            }
            if failure == nil { failure = error.localizedDescription }
            if error is UFitBrandOutfitIntegrationFailure { retryMore = false }
            failureAtEnd = more
        }
    }
    func retry() async { await load(more: retryMore) }
    func cancelLoading() { generation = UUID(); operation = .idle }
}
