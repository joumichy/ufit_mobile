import SwiftUI

struct UFitPublicProfileHost: View {
    let store: UFitPublicProfileStore
    let session: UFitSessionStore
    let onBack: () -> Void
    let onSignIn: () -> Void
    let onOpen: (Outfit) -> Void
    var body: some View {
        UFitPublicProfileContent(profile: store.profile, outfits: store.tiles, isLoading: store.isLoading, isLoadingMore: store.isLoadingMore,
            hasMore: store.hasMore, followState: store.followState, isFollowingBusy: store.isFollowingBusy, message: store.message,
            onBack: onBack, onRefresh: { await store.load() }, onMore: { Task { await store.more() } }, onFollow: follow,
            onRetryFollow: { Task { await store.loadFollow(refreshProfile: true) } },
            onOpen: { id in if let outfit = store.outfits.first(where: { $0.id == id }) { onOpen(outfit) } })
            .task {
                if !store.hasLoaded { await store.load() }
                else { await store.loadFollow(refreshProfile: true) }
            }
            .onChange(of: session.user?.id) { _, _ in Task { await store.loadFollow(refreshProfile: true) } }
    }
    private func follow() {
        if case .signIn = store.followState { onSignIn() }
        else { Task { await store.toggleFollow() } }
    }
}
