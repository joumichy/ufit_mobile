import SwiftUI

struct HomeFeedContentView: View {
    let outfits: [Outfit]
    let savedStates: [String: UFitSavedOutfitState]
    let isAuthenticated: Bool
    @Binding var expandedOutfitIDs: Set<String>
    @Binding var photoIDs: [String: String]
    @Binding var visibleOutfitID: String?
    let onToggleSaved: (Outfit) -> Void
    let onOutfitTap: (Outfit) -> Void
    let onAuthorTap: (OutfitAuthor) -> Void
    let onItemTap: (Outfit, String) -> Void
    var feedback: String? = nil
    var loadError: String? = nil
    var onDismissFeedback: (() -> Void)? = nil
    var onRetry: (() -> Void)? = nil
    var isLoadingMore = false
    var moreError: String?
    var onApproachOutfit: ((String) -> Void)? = nil
    var onRetryMore: (() -> Void)? = nil
    private enum Copy {
        static let retry = String(localized: "Réessayer")
        static let retryMore = String(localized: "Réessayer la suite")
        static let loadingMore = String(localized: "Chargement des tenues…")
    }
    private enum StatusContrast {
        static let height: CGFloat = 112
        static let opacity = 0.62
        static let plateau = 0.65
        static let end = 1.0
    }
    var body: some View {
        ScrollView(.vertical) {
            LazyVStack(spacing: .zero) {
                ForEach(outfits) { outfit in
                    OutfitFeedCard(
                        outfit: outfit,
                        savedState: savedStates[outfit.id] ?? (isAuthenticated ? .unknown : .notSaved),
                        onLike: { onToggleSaved(outfit) },
                        onOutfitTap: { onOutfitTap(outfit) },
                        onAuthorTap: { if let author = outfit.author { onAuthorTap(author) } },
                        onItemTap: { onItemTap(outfit, $0) },
                        showingPieces: Binding(get: { expandedOutfitIDs.contains(outfit.id) }, set: { expanded in
                            if expanded { expandedOutfitIDs.insert(outfit.id) } else { expandedOutfitIDs.remove(outfit.id) }
                        }), selectedPhotoID: Binding(get: { photoIDs[outfit.id] }, set: { photoIDs[outfit.id] = $0 })
                    )
                    .containerRelativeFrame([.horizontal, .vertical])
                    .onAppear { onApproachOutfit?(outfit.id) }
                }
            }
            .scrollTargetLayout()
        }
        .scrollIndicators(.hidden)
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $visibleOutfitID)
        .background(Color.ufitInk)
        .ignoresSafeArea(edges: .top)
        .overlay(alignment: .top) {
            if !outfits.isEmpty {
                LinearGradient(stops: [
                    .init(color: .black.opacity(StatusContrast.opacity), location: .zero),
                    .init(color: .black.opacity(StatusContrast.opacity), location: StatusContrast.plateau),
                    .init(color: .clear, location: StatusContrast.end)
                ], startPoint: .top, endPoint: .bottom)
                    .frame(height: StatusContrast.height).ignoresSafeArea(edges: .top)
                    .allowsHitTesting(false).accessibilityHidden(true)
            }
        }
        .overlay(alignment: .top) {
            VStack(spacing: UFitSpace.xs) {
                if !outfits.isEmpty, let loadError {
                    UFitNotice(message: loadError, kind: .error)
                    if let onRetry { UFitActionButton(title: Copy.retry, kind: .secondary, action: onRetry) }
                } else if let moreError {
                    UFitNotice(message: moreError, kind: .error)
                    if let onRetryMore { UFitActionButton(title: Copy.retryMore, kind: .secondary, action: onRetryMore) }
                } else if isLoadingMore {
                    UFitLoading(Copy.loadingMore).padding(UFitSpace.sm)
                        .background(Color.ufitCanvas, in: RoundedRectangle(cornerRadius: UFitRadius.action))
                } else if let feedback { UFitNotice(message: feedback, onDismiss: onDismissFeedback) }
            }.padding(.horizontal, UFitSpace.page).padding(.top, UFitSpace.md)
        }
    }
}
