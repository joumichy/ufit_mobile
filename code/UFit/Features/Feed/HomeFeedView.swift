import SwiftUI

struct HomeFeedView: View {
    let store: MarketplaceStore
    let onOutfitTap: (Outfit) -> Void
    let onCreatorTap: () -> Void

    var body: some View {
        HomeFeedContentView(
            outfits: store.outfits,
            savedOutfitIDs: store.savedOutfitIDs,
            feedErrorMessage: store.feedErrorMessage,
            onToggleSaved: toggleLike,
            onOutfitTap: onOutfitTap,
            onCreatorTap: onCreatorTap
        )
        .task { await store.loadFeedIfNeeded() }
        .refreshable { await store.refreshFeed() }
    }
}

private extension HomeFeedView {
    func toggleLike(_ outfit: Outfit) {
        Task {
            await store.toggleSaved(outfit: outfit)
        }
    }
}

#Preview {
    HomeFeedView(store: MarketplaceStore.live(), onOutfitTap: { _ in }, onCreatorTap: {})
}
