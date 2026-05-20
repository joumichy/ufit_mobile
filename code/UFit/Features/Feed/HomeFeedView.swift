import SwiftUI

struct HomeFeedView: View {
    let onOutfitTap: (Outfit) -> Void
    let onCreatorTap: () -> Void

    @State private var likedOutfitIDs = Set<Int>()

    var body: some View {
        GeometryReader { proxy in
            ScrollView(.vertical) {
                LazyVStack(spacing: 0) {
                    ForEach(SampleData.outfits) { outfit in
                        OutfitFeedCard(
                            outfit: outfit,
                            isLiked: likedOutfitIDs.contains(outfit.id),
                            viewportSize: proxy.size,
                            onLike: { toggleLike(outfit.id) },
                            onOutfitTap: { onOutfitTap(outfit) },
                            onCreatorTap: onCreatorTap
                        )
                        .frame(width: proxy.size.width, height: proxy.size.height)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollIndicators(.hidden)
            .scrollTargetBehavior(.paging)
            .background(Color.black)
            .ignoresSafeArea()
        }
    }
}

private extension HomeFeedView {
    func toggleLike(_ id: Int) {
        withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
            if likedOutfitIDs.contains(id) {
                likedOutfitIDs.remove(id)
            } else {
                likedOutfitIDs.insert(id)
            }
        }
    }
}

#Preview {
    HomeFeedView(onOutfitTap: { _ in }, onCreatorTap: {})
}
