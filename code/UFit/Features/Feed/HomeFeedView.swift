import SwiftUI

struct HomeFeedView: View {
    @Bindable var store: MarketplaceStore
    let onOutfitTap: (Outfit) -> Void
    let onAuthorTap: (OutfitAuthor) -> Void
    var onItemTap: (Outfit, String) -> Void = {_,_ in}
    var onSignIn: () -> Void = {}

    var body: some View {
        HomeFeedContentView(outfits: store.outfits, savedOutfitIDs: store.savedOutfitIDs, savingOutfitIDs: store.savingOutfitIDs,
            expandedOutfitIDs: $store.expandedFeedIDs, photoIDs: $store.feedPhotoIDs, visibleOutfitID: $store.visibleFeedOutfitID,
            onToggleSaved: toggleLike, onOutfitTap: onOutfitTap, onAuthorTap: onAuthorTap, onItemTap: onItemTap,
            feedback: store.actionMessage, loadError: store.feedErrorMessage,
            onDismissFeedback: { store.actionMessage = nil }, onRetry: { Task { await store.refreshFeed() } })
        .task {
            await store.loadFeedIfNeeded()
        }
        .ufitRefreshable {
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
