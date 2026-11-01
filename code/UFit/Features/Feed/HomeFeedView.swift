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
            onToggleSaved: toggleLike, onOutfitTap: onOutfitTap, onAuthorTap: onAuthorTap, onItemTap: onItemTap)
        .task {
            await store.loadFeedIfNeeded()
        }
        .refreshable {
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
        if store.isLoadingFeed { return .loading }
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
