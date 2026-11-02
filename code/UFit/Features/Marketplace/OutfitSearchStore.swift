import Foundation
import Observation

@MainActor @Observable
final class UFitOutfitSearchStore {
    var criteria = UFitOutfitSearchCriteria() {
        didSet { if oldValue != criteria { invalidate() } }
    }
    var visibleOutfitID: String?
    private(set) var outfits: [Outfit] = []
    private(set) var isLoading = false
    private(set) var hasLoaded = false
    private(set) var message: String?
    private(set) var isLoadingMore = false
    private(set) var moreError: String?
    private(set) var options: UFitOutfitDiscoveryOptions?
    private(set) var isLoadingOptions = false
    private(set) var optionsError: String?
    @ObservationIgnored private let client: UFitAPIClient
    @ObservationIgnored private var generation = UUID()
    @ObservationIgnored private var nextCursor: String?
    @ObservationIgnored private var consumedCursors = Set<String>()
    var hasMore: Bool { nextCursor != nil }
    var isQueryTooLong: Bool { criteria.query.trimmingCharacters(in: .whitespacesAndNewlines).utf16.count > UFitOutfitDiscoveryHTTP.queryMax }
    var filterSummary: String {
        [options?.tags.first(where: { $0.id == criteria.styleID })?.label,
         options?.tags.first(where: { $0.id == criteria.occasionID })?.label,
         criteria.itemType?.label].compactMap { $0 }.joined(separator: UFitOutfitDiscoveryHTTP.separator)
    }
    init(client: UFitAPIClient) { self.client = client }

    func loadOptions() async {
        guard !isLoadingOptions else { return }
        isLoadingOptions = true; optionsError = nil
        defer { isLoadingOptions = false }
        do { options = try await client.fetchOutfitDiscoveryOptions() }
        catch is CancellationError {}
        catch { optionsError = UFitOutfitSearchCopy.optionsFailed }
    }
    func loadIfNeeded() async {
        guard !hasLoaded else { return }
        await search(debounce: true)
    }
    func search(debounce: Bool = false) async {
        let request = UUID(); generation = request
        let requestedCriteria = criteria
        isLoading = true; isLoadingMore = false; message = nil; moreError = nil
        defer { if generation == request { isLoading = false } }
        guard !isQueryTooLong else {
            message = UFitOutfitSearchCopy.queryTooLong; return
        }
        do {
            if debounce { try await Task.sleep(for: .milliseconds(UFitOutfitDiscoveryHTTP.debounceMilliseconds)) }
            let page = try await client.fetchOutfitFeed(discovery: requestedCriteria)
            try Task.checkCancellation()
            guard generation == request, criteria == requestedCriteria else { return }
            outfits = page.items.map { $0.toOutfit() }; nextCursor = page.nextCursor; consumedCursors = []
            hasLoaded = true
            if let visibleOutfitID, !outfits.contains(where: { $0.id == visibleOutfitID }) { self.visibleOutfitID = nil }
        } catch is CancellationError {}
        catch { if generation == request { message = UFitOutfitSearchCopy.failedMessage } }
    }
    func more() async {
        guard !isLoading, !isLoadingMore, message == nil, let cursor = nextCursor else { return }
        let request = generation, requestedCriteria = criteria
        isLoadingMore = true; moreError = nil
        defer { if generation == request { isLoadingMore = false } }
        do {
            let page = try await client.fetchOutfitFeed(cursor: cursor, discovery: requestedCriteria)
            try Task.checkCancellation()
            guard generation == request, criteria == requestedCriteria else { return }
            guard !consumedCursors.contains(cursor), Set(outfits.map(\.id)).isDisjoint(with: page.items.map(\.id)) else {
                throw UFitPublicProfileContractError.outfits
            }
            outfits.append(contentsOf: page.items.map { $0.toOutfit() }); nextCursor = page.nextCursor; consumedCursors.insert(cursor)
        } catch is CancellationError {}
        catch { if generation == request { moreError = UFitOutfitSearchCopy.moreFailed } }
    }
    private func invalidate() {
        generation = UUID(); outfits = []; visibleOutfitID = nil; nextCursor = nil; consumedCursors = []
        isLoading = false; isLoadingMore = false; hasLoaded = false; message = nil; moreError = nil
    }
}
