import Foundation
import Observation

@MainActor @Observable
final class UFitPublicProfileStore {
    let reference: UFitPublicProfileReference
    private(set) var profile: UFitPublicProfilePresentation?
    private(set) var outfits: [Outfit] = []
    private(set) var hasLoaded = false
    private(set) var isLoading = false
    private(set) var isLoadingMore = false
    private(set) var isFollowingBusy = false
    private(set) var followState = UFitPublicFollowState.hidden
    private(set) var message: String?
    @ObservationIgnored private let client: UFitAPIClient
    @ObservationIgnored private let session: UFitSessionStore
    @ObservationIgnored private var nextCursor: String?
    @ObservationIgnored private var seenCursors = Set<String>()
    @ObservationIgnored private var generation = UUID()
    @ObservationIgnored private var followGeneration = UUID()
    private enum HTTP { static let missing = 404; static let unauthorized = 401; static let pageSize = 20 }
    init(reference: UFitPublicProfileReference, client: UFitAPIClient, session: UFitSessionStore) {
        self.reference = reference; self.client = client; self.session = session
    }
    var hasMore: Bool { nextCursor != nil }
    var tiles: [UFitPublicOutfitTile] { outfits.map { .init(id: $0.id, title: $0.title, image: $0.imageName, price: $0.price) } }
    func load() async {
        guard !isLoading else { return }
        generation = UUID(); let request = generation
        isLoading = true; isLoadingMore = false; message = nil
        defer { if generation == request { isLoading = false } }
        do {
            async let profileRequest = client.fetchPublicProfile(reference)
            let page = try await client.fetchOutfitFeed(limit: HTTP.pageSize, author: reference)
            let value = try await profileRequest
            guard generation == request else { return }
            profile = value; outfits = page.items.map { $0.toOutfit() }; nextCursor = page.nextCursor; seenCursors = []; hasLoaded = true
            await loadFollow()
        } catch { if generation == request { receive(error) } }
    }
    func more() async {
        guard !isLoading, !isLoadingMore, let cursor = nextCursor else { return }
        let request = generation
        isLoadingMore = true; message = nil
        defer { if generation == request { isLoadingMore = false } }
        do {
            let page = try await client.fetchOutfitFeed(limit: HTTP.pageSize, cursor: cursor, author: reference)
            guard generation == request else { return }
            guard !seenCursors.contains(cursor), Set(outfits.map(\.id)).isDisjoint(with: page.items.map(\.id)) else { throw UFitPublicProfileContractError.outfits }
            outfits.append(contentsOf: page.items.map { $0.toOutfit() }); nextCursor = page.nextCursor; seenCursors.insert(cursor)
        } catch { if generation == request { receive(error) } }
    }
    func loadFollow(refreshProfile: Bool = false) async {
        guard !isFollowingBusy else { return }
        followGeneration = UUID(); let request = followGeneration
        guard reference.kind == .creator, profile != nil else { followState = .hidden; return }
        guard let userID = session.user?.id else { followState = .signIn; return }
        followState = .loading
        do {
            let following = try await client.fetchCreatorFollow(id: reference.id)
            guard followGeneration == request, session.user?.id == userID, profile != nil else { return }
            followState = .ready(following)
            if refreshProfile { await refreshHeader(request: request, userID: userID) }
        } catch {
            guard followGeneration == request, session.user?.id == userID else { return }
            if hasStatus(error, HTTP.unauthorized) { followState = .signIn }
            else { followState = .failed(error.localizedDescription) }
            if hasStatus(error, HTTP.missing) { receive(error) }
        }
    }
    func toggleFollow() async {
        guard !isFollowingBusy, reference.kind == .creator, profile != nil, let userID = session.user?.id,
              case .ready(let following) = followState else { return }
        followGeneration = UUID(); let request = followGeneration
        isFollowingBusy = true; message = nil
        defer { if followGeneration == request { isFollowingBusy = false } }
        do {
            let updated = try await client.setCreatorFollow(id: reference.id, following: !following)
            guard followGeneration == request, session.user?.id == userID, profile != nil else { return }
            followState = .ready(updated)
            await refreshHeader(request: request, userID: userID)
        } catch {
            guard followGeneration == request, session.user?.id == userID else { return }
            if hasStatus(error, HTTP.unauthorized) { followState = .signIn }
            else { followState = .failed(error.localizedDescription) }
            if hasStatus(error, HTTP.missing) { receive(error) }
        }
    }
    private func refreshHeader(request: UUID, userID: String) async {
        do {
            let value = try await client.fetchPublicProfile(reference)
            if followGeneration == request, session.user?.id == userID, profile != nil { profile = value }
        } catch { if followGeneration == request, session.user?.id == userID { receive(error) } }
    }
    private func hasStatus(_ error: Error, _ status: Int) -> Bool {
        guard let api = error as? UFitAPIError, case .requestFailed(let received, _, _) = api else { return false }
        return received == status
    }
    private func receive(_ error: Error) {
        message = error.localizedDescription
        if hasStatus(error, HTTP.missing) {
            profile = nil; outfits = []; nextCursor = nil; followState = .hidden
        }
    }
}
