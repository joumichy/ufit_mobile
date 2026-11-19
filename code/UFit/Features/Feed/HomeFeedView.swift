import SwiftUI

struct HomeFeedView: View {
    @Bindable var store: MarketplaceStore
    let onOutfitTap: (Outfit) -> Void
    let onAuthorTap: (OutfitAuthor) -> Void
    var onItemTap: (Outfit, String) -> Void = {_,_ in}
    var onSignIn: () -> Void = {}

    var body: some View {
        HomeFeedContentView(outfits: store.outfits, savedStates: store.savedStates, isAuthenticated: store.isAuthenticated,
            expandedOutfitIDs: $store.expandedFeedIDs, photoIDs: $store.feedPhotoIDs, visibleOutfitID: $store.visibleFeedOutfitID,
            onToggleSaved: toggleLike, onOutfitTap: onOutfitTap, onAuthorTap: onAuthorTap, onItemTap: onItemTap,
            feedback: store.feedFeedback, loadError: store.feedErrorMessage,
            onDismissFeedback: store.dismissFeedFeedback, onRetry: { Task { await store.refreshFeed() } },
            isLoadingMore: store.isLoadingMoreFeed, moreError: store.feedMoreError,
            onApproachOutfit: { id in Task { await store.loadMoreFeedIfNeeded(near: id) } },
            onRetryMore: { Task { await store.retryMoreFeed() } })
        .task {
            await store.loadFeedIfNeeded()
            await store.loadSavedStates(ids: store.outfits.map(\.id))
        }
        .onChange(of: store.isLoadingFeed) { _, loading in
            if !loading, let id = store.visibleFeedOutfitID { Task { await store.loadMoreFeedIfNeeded(near: id) } }
        }
        .ufitRefreshable(isEnabled: !store.isLoadingFeed) {
            await store.refreshFeed()
        }
        .overlay {
            if store.outfits.isEmpty {
                UFitFeedStatusView(status: status) { Task { await store.refreshFeed() } }
            }
        }

    }
}


private extension HomeFeedView {
    var status: UFitFeedStatus {
        if store.isLoadingFeed || (!store.hasLoadedFeed && store.feedErrorMessage == nil) { return .loading }
        if let message = store.feedErrorMessage { return .failed(message) }
        return .empty
    }

    func toggleLike(_ outfit: Outfit) {
        guard store.isAuthenticated else { onSignIn(); return }
        Task {
            await store.toggleSaved(outfit: outfit)
        }
    }
}

#Preview {
    HomeFeedView(store: MarketplaceStore.live(), onOutfitTap: { _ in }, onAuthorTap: {_ in})
}
