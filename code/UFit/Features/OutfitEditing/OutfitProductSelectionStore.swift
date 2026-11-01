import Foundation
import Observation

@MainActor @Observable
final class UFitOutfitProductSelectionStore: Identifiable {
    let id = UUID()
    let form: UFitOutfitFormStore
    var search = String()
    private(set) var products: [UFitOutfitProductChoice] = []
    private(set) var isLoading = false
    private(set) var hasLoaded = false
    private(set) var isLoadingMore = false
    private(set) var nextCursor: String?
    private(set) var message: String?
    @ObservationIgnored private var generation = UUID()
    @ObservationIgnored private var activeSearch = String()
    @ObservationIgnored private var pageCursors = Set<String>()
    init(form: UFitOutfitFormStore) { self.form = form }
    var selectedIDs: Set<String> { Set(form.draft.pieces.compactMap { $0.product?.id }) }
    func cancel() { generation = UUID() }
    func load() async {
        guard form.collection.isCurrentAccount else { return }
        generation = UUID(); let request = generation
        activeSearch = UFitOutfitInput.trimmed(search)
        isLoading = true; isLoadingMore = false; message = nil; products = []; hasLoaded = false; nextCursor = nil; pageCursors = []
        defer { if generation == request { isLoading = false } }
        do {
            let page = try await form.collection.client.fetchOutfitProductSelection(search: activeSearch, cursor: nil)
            guard generation == request, form.collection.isCurrentAccount else { return }
            products = page.items.map { $0.choice() }; nextCursor = page.nextCursor; hasLoaded = true
        } catch { if generation == request && form.collection.isCurrentAccount { message = error.localizedDescription } }
    }
    func more() async {
        guard !isLoading, !isLoadingMore, let cursor = nextCursor, form.collection.isCurrentAccount else { return }
        let request = generation; isLoadingMore = true; message = nil
        defer { if generation == request { isLoadingMore = false } }
        do {
            let page = try await form.collection.client.fetchOutfitProductSelection(search: activeSearch, cursor: cursor)
            guard generation == request, form.collection.isCurrentAccount else { return }
            guard !pageCursors.contains(cursor), Set(products.map(\.id)).isDisjoint(with: page.items.map(\.id)) else { throw UFitOutfitContractError.page }
            products.append(contentsOf: page.items.map { $0.choice() }); nextCursor = page.nextCursor; pageCursors.insert(cursor)
        } catch { if generation == request && form.collection.isCurrentAccount { message = error.localizedDescription } }
    }
    func select(_ choice: UFitOutfitProductChoice) -> Bool {
        guard form.collection.isCurrentAccount, !form.isBusy, !selectedIDs.contains(choice.id),
              products.contains(where: { $0.id == choice.id }), form.draft.pieces.count < UFitOutfitInput.itemsMax else { return false }
        form.draft.pieces.append(.init(product: choice)); return true
    }
}
