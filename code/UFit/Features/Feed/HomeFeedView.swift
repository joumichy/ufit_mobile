import SwiftUI

struct HomeFeedView: View {
    @Bindable var store: MarketplaceStore
    let onOutfitTap: (Outfit) -> Void
    let onAuthorTap: (OutfitAuthor) -> Void
    var onSignIn: () -> Void = {}

    var body: some View {
        ScrollView(.vertical) {
            LazyVStack(spacing: 0) {
                ForEach(store.outfits) { outfit in
                    OutfitFeedCard(
                        outfit: outfit,
                        isLiked: store.savedOutfitIDs.contains(outfit.id),
                        onLike: { toggleLike(outfit) },
                        onOutfitTap: { onOutfitTap(outfit) },
                        onAuthorTap: { if let author = outfit.author { onAuthorTap(author) } },
                        isSaving: store.savingOutfitIDs.contains(outfit.id)
                    )
                    .containerRelativeFrame([.horizontal, .vertical])
                }
            }
            .scrollTargetLayout()
        }
        .scrollIndicators(.hidden)
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $store.visibleFeedOutfitID)
        .background(Color.black)
        .ignoresSafeArea()
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
