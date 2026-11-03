import Foundation
import Observation

@MainActor @Observable
final class UFitRefundRecoveryStore {
    let session: UFitSessionStore
    var search = String()
    private(set) var kind: UFitRefundRecoveryKind?
    private(set) var items = [UFitRefundRecoverySummaryDTO]()
    private(set) var totalCount: Int?
    private(set) var nextCursor: String?
    private(set) var isLoading = false
    private(set) var hasLoaded = false
    private(set) var openingIDs = Set<UFitRefundRecoveryReference>()
    private(set) var message: String?
    @ObservationIgnored private let ownerID: String?
    @ObservationIgnored private var generation = UUID()
    @ObservationIgnored private var appliedSearch = String()
    init(session: UFitSessionStore) {self.session = session; ownerID = session.user?.id}
    var isCurrentAccount: Bool {ownerID != nil && ownerID == session.user?.id && session.user?.canAdminister == true}
    var rows: [UFitRefundRecoveryRow] {items.map(\.row)}
    var isFiltered: Bool {kind != nil || !UFitServerTextInput.trimmed(search).isEmpty}
    func cancelLoading() {generation = UUID(); isLoading = false; openingIDs = []}
    func searchChanged() async {
        let term = UFitServerTextInput.trimmed(search)
        guard isCurrentAccount, !hasLoaded || term != appliedSearch else {return}
        cancelLoading(); items = []; totalCount = nil; nextCursor = nil; hasLoaded = false; message = nil
        let request = generation
        do {if !term.isEmpty {try await Task.sleep(for: UFitRefundRecoveryCopy.searchDebounce)}} catch {return}
        guard generation == request, isCurrentAccount, !hasLoaded || term != appliedSearch else {return}
        await load()
    }
    func select(_ kind: UFitRefundRecoveryKind?) async {
        guard isCurrentAccount, kind != self.kind else {return}
        cancelLoading(); self.kind = kind; items = []; totalCount = nil; nextCursor = nil; hasLoaded = false
        await load()
    }
    func reset() async {
        cancelLoading(); search = String(); kind = nil; items = []; totalCount = nil; nextCursor = nil; hasLoaded = false
        await load()
    }
    func load(reset: Bool = true) async {
        guard isCurrentAccount, !isLoading, reset || nextCursor != nil else {return}
        let request = generation, cursor = reset ? nil : nextCursor, term = reset ? UFitServerTextInput.trimmed(search) : appliedSearch
        isLoading = true; message = nil
        defer {if generation == request {isLoading = false}}
        do {
            let page = try await session.api.fetchRefundRecoveries(kind: kind, search: term, cursor: cursor)
            guard generation == request, isCurrentAccount else {return}
            if reset {items = page.items}
            else {
                guard totalCount == page.totalCount, Set(page.items.map(\.reference)).isDisjoint(with: Set(items.map(\.reference))) else {throw UFitRefundRecoveryFailure.changed}
                items.append(contentsOf: page.items)
            }
            totalCount = page.totalCount; nextCursor = page.nextCursor; appliedSearch = term; hasLoaded = true
        } catch {
            guard generation == request, isCurrentAccount else {return}
            if UFitRefundRecoveryFailure.revoked(error) {items = []; totalCount = nil; nextCursor = nil; hasLoaded = false}
            message = UFitRefundRecoveryFailure.message(error)
        }
    }
    func open(_ reference: UFitRefundRecoveryReference) async -> UFitRefundRecoveryDetailStore? {
        guard isCurrentAccount, items.contains(where: {$0.reference == reference}), !openingIDs.contains(reference) else {return nil}
        let request = generation; openingIDs.insert(reference)
        defer {if generation == request {openingIDs.remove(reference)}}
        do {
            let document = try await session.api.fetchRefundRecovery(reference)
            guard generation == request, isCurrentAccount else {return nil}
            return UFitRefundRecoveryDetailStore(document: document, collection: self)
        } catch {
            guard generation == request, isCurrentAccount else {return nil}
            if UFitRefundRecoveryFailure.missing(error) {remove(reference)}
            if UFitRefundRecoveryFailure.revoked(error) {items = []; totalCount = nil; nextCursor = nil; hasLoaded = false}
            message = UFitRefundRecoveryFailure.message(error); return nil
        }
    }
    func remove(_ reference: UFitRefundRecoveryReference) {items.removeAll {$0.reference == reference}; totalCount = nil; nextCursor = nil; hasLoaded = false}
}

@MainActor @Observable
final class UFitRefundRecoveryDetailStore {
    private(set) var document: UFitRefundRecoveryDetailDTO?
    private(set) var isLoading = false
    private(set) var unavailable = false
    private(set) var message: String?
    let reference: UFitRefundRecoveryReference
    let collection: UFitRefundRecoveryStore
    @ObservationIgnored private var generation = UUID()
    init(document: UFitRefundRecoveryDetailDTO, collection: UFitRefundRecoveryStore) {self.document = document; reference = document.summary.reference; self.collection = collection}
    var isCurrentAccount: Bool {collection.isCurrentAccount}
    var presentation: UFitRefundRecoveryDocument? {document?.presentation}
    func cancelLoading() {generation = UUID(); isLoading = false}
    func load() async {
        guard isCurrentAccount, !isLoading else {return}
        let request = generation; isLoading = true; message = nil
        defer {if generation == request {isLoading = false}}
        do {
            let value = try await collection.session.api.fetchRefundRecovery(reference)
            guard generation == request, isCurrentAccount else {return}
            document = value; unavailable = false
        } catch {
            guard generation == request, isCurrentAccount else {return}
            if UFitRefundRecoveryFailure.missing(error) || UFitRefundRecoveryFailure.revoked(error) {
                document = nil; unavailable = true; collection.remove(reference)
            }
            message = UFitRefundRecoveryFailure.message(error)
        }
    }
    func report(_ error: Error) {message = UFitRefundRecoveryFailure.message(error)}
}
