import SwiftUI

struct HomeFeedContentView: View {
    let outfits: [Outfit]
    let savedOutfitIDs: Set<String>
    let savingOutfitIDs: Set<String>
    @Binding var expandedOutfitIDs: Set<String>
    @Binding var photoIDs: [String: String]
    @Binding var visibleOutfitID: String?
    let onToggleSaved: (Outfit) -> Void
    let onOutfitTap: (Outfit) -> Void
    let onAuthorTap: (OutfitAuthor) -> Void
    let onItemTap: (Outfit, String) -> Void
    var body: some View {
        ScrollView(.vertical) {
            LazyVStack(spacing: 0) {
                ForEach(outfits) { outfit in
                    OutfitFeedCard(
                        outfit: outfit,
                        isLiked: savedOutfitIDs.contains(outfit.id),
                        onLike: { onToggleSaved(outfit) },
                        onOutfitTap: { onOutfitTap(outfit) },
                        onAuthorTap: { if let author = outfit.author { onAuthorTap(author) } },
                        isSaving: savingOutfitIDs.contains(outfit.id), onItemTap: { onItemTap(outfit, $0) },
                        showingPieces: Binding(get: { expandedOutfitIDs.contains(outfit.id) }, set: { expanded in
                            if expanded { expandedOutfitIDs.insert(outfit.id) } else { expandedOutfitIDs.remove(outfit.id) }
                        }), selectedPhotoID: Binding(get: { photoIDs[outfit.id] }, set: { photoIDs[outfit.id] = $0 })
                    )
                    .containerRelativeFrame([.horizontal, .vertical])
                }
            }
            .scrollTargetLayout()
        }
        .scrollIndicators(.hidden)
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $visibleOutfitID)
        .background(Color.black)
        .ignoresSafeArea()
    }
}
