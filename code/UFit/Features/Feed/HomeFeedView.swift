import SwiftUI

struct HomeFeedView: View {
    let store: MarketplaceStore
    let onOutfitTap: (Outfit) -> Void
    let onCreatorTap: () -> Void

    var body: some View {
        ScrollView(.vertical) {
            LazyVStack(spacing: 0) {
                ForEach(store.outfits) { outfit in
                    OutfitFeedCard(
                        outfit: outfit,
                        isLiked: store.savedOutfitIDs.contains(outfit.id),
                        onLike: { toggleLike(outfit) },
                        onOutfitTap: { onOutfitTap(outfit) },
                        onCreatorTap: onCreatorTap
                    )
                    .containerRelativeFrame([.horizontal, .vertical])
                }
            }
            .scrollTargetLayout()
        }
        .scrollIndicators(.hidden)
        .scrollTargetBehavior(.paging)
        .background(Color.black)
        .ignoresSafeArea()
        .task {
            await store.loadFeedIfNeeded()
        }
        .refreshable {
            await store.refreshFeed()
        }
        .overlay(alignment: .top) {
            if let message = store.feedErrorMessage {
                Text(message)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.ufitInk)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(.white.opacity(0.92), in: Capsule())
                    .padding(.top, 58)
            }
        }
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
