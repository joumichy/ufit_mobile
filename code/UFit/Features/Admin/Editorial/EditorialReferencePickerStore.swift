import Foundation
import Observation

@MainActor @Observable
final class UFitEditorialReferencePickerStore: Identifiable {
    let id = UUID()
    let collection: UFitEditorialAdministrationStore
    var kind = UFitEditorialKind.outfit
    var search = String()
    private(set) var rows: [UFitEditorialReference] = []
    private(set) var isLoading = false
    private(set) var isLoadingMore = false
    private(set) var hasLoaded = false
    private(set) var nextCursor: String?
    private(set) var message: String?
    private(set) var moreFailed = false
    @ObservationIgnored private var generation = UUID()
    @ObservationIgnored private var query = String()
    @ObservationIgnored private var cursors = Set<String>()
    init(collection: UFitEditorialAdministrationStore) { self.collection = collection }
    func cancel() { generation = UUID(); isLoading = false; isLoadingMore = false }
    func filter(_ kind: UFitEditorialKind) async { self.kind = kind; await load() }
    func load(more: Bool = false) async {
        guard collection.isCurrentAccount else { return }
        if more { guard !isLoading, !isLoadingMore, nextCursor != nil else { return } }
        else { cancel(); query = search.trimmingCharacters(in: .whitespacesAndNewlines); rows = []; nextCursor = nil; cursors = []; hasLoaded = false }
        moreFailed = false
        guard query.unicodeScalars.count <= UFitOutfitDiscoveryHTTP.queryMax else { message = UFitEditorialAdminCopy.tooLong; return }
        let request = generation, kind = kind, cursor = more ? nextCursor : nil
        if more { isLoadingMore = true } else { isLoading = true }; message = nil
        defer { if generation == request { isLoading = false; isLoadingMore = false } }
        do {
            let selected: [UFitEditorialReference], next: String?
            if kind == .outfit {
                let result = try await collection.session.api.fetchOutfitFeed(cursor: cursor, discovery: .init(query: query))
                selected = result.items.map { item in
                    let outfit = item.toOutfit()
                    return .init(kind: .outfit, contentID: outfit.id, title: outfit.title, imageURL: outfit.imageName, available: true)
                }; next = result.nextCursor
            } else {
                let page = try await collection.session.api.fetchOutfitProductSelection(search: query, cursor: cursor)
                selected = page.items.map { .init(kind: .product, contentID: $0.id, title: $0.product.name,
                    imageURL: $0.product.images.sorted { $0.position < $1.position }.first?.url, available: true) }; next = page.nextCursor
            }
            guard generation == request, collection.isCurrentAccount else { return }
            guard Set(rows.map(\.id)).isDisjoint(with: selected.map(\.id)), cursor == nil || !cursors.contains(cursor!) else { throw UFitEditorialFailure.contract }
            rows.append(contentsOf: selected); nextCursor = next; hasLoaded = true
            if let cursor { cursors.insert(cursor) }
        } catch { if generation == request, collection.isCurrentAccount { message = more ? UFitEditorialCopy.moreFailed : UFitEditorialAdminCopy.searchFailed; moreFailed = more } }
    }
    func select(_ reference: UFitEditorialReference) -> Bool {
        guard collection.allowsMutation, let editor = collection.editor,
              rows.contains(where: { $0.id == reference.id }), !editor.draft.references.contains(where: { $0.id == reference.id }),
              editor.draft.references.count < UFitEditorialHTTP.maximumItems else { return false }
        editor.draft.references.append(reference); return true
    }
}
