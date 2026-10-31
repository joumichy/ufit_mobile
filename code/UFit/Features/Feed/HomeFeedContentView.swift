import SwiftUI

struct HomeFeedContentView: View {
    let outfits: [Outfit]
    let savedOutfitIDs: Set<String>
    let feedErrorMessage: String?
    let onToggleSaved: (Outfit) -> Void
    let onOutfitTap: (Outfit) -> Void
    let onCreatorTap: () -> Void

    var body: some View {
        ScrollView(.vertical) {
            LazyVStack(spacing: 0) {
                ForEach(outfits) { outfit in
                    OutfitFeedCard(
                        outfit: outfit,
                        isLiked: savedOutfitIDs.contains(outfit.id),
                        onLike: { onToggleSaved(outfit) },
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
        .overlay(alignment: .top) {
            if let message = feedErrorMessage {
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
