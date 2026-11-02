import SwiftUI

struct OutfitFeedCard: View {
    let outfit: Outfit
    let savedState: UFitSavedOutfitState
    let onLike: () -> Void
    let onOutfitTap: () -> Void
    let onAuthorTap: () -> Void
    var onItemTap: (String) -> Void = {_ in}
    @Binding var showingPieces: Bool
    @State private var pendingArticleID: String?
    @State private var selectedReference: OutfitProduct?
    @Binding var selectedPhotoID: String?
    @Environment(\.dynamicTypeSize) private var typeSize

    private enum Copy {
        static let pieces = String(localized: "Voir les pièces")
        static let hide = String(localized: "Masquer les pièces")
        static let empty = String(localized: "Aucune pièce associée")
        static let piece = String(localized: "Voir la pièce")
        static let article = String(localized: "Voir l’article")
        static let close = String(localized: "Fermer la référence")
        static let closeIcon = "xmark"
        static let bag = "bag"
    }
    private enum Layout {
        static let spacing: CGFloat = UFitSpace.lg
        static let captionSpacing: CGFloat = 14
        static let horizontal: CGFloat = UFitSpace.xl
        static let bottom: CGFloat = UFitSpace.xxl
        static let avatar: CGFloat = 44
        static let title: CGFloat = UFitTypography.Size.title
        static let initials: CGFloat = UFitTypography.Size.small
        static let overlayOpacity = 0.72
        static let avatarOpacity = 0.18
        static let unavailableOpacity = 0.4; static let availableOpacity = 1.0
        static let ribbonBottom: CGFloat = 190
        static let titleLines = 3
        static let dotsBottom: CGFloat = UFitSpace.xs; static let step = 1
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                if outfit.photos.isEmpty {
                    FashionImage(source: outfit.imageName).frame(width: proxy.size.width, height: proxy.size.height).clipped()
                } else {
                    UFitOutfitPhotoPages(photos: outfit.photos, selection: photoSelection, size: proxy.size)
                }
                LinearGradient(colors: [.clear, .clear, .black.opacity(Layout.overlayOpacity)], startPoint: .top, endPoint: .bottom).allowsHitTesting(false)
                if outfit.photos.count > Layout.step {
                    photoIndicators.padding(.bottom, Layout.dotsBottom)
                }
                if showingPieces && !outfit.products.isEmpty {
                    VStack { Spacer(); HStack { Spacer(); ribbon }.padding(.horizontal, Layout.horizontal) }
                        .padding(.bottom, Layout.ribbonBottom)
                }
                Group {
                    if typeSize.isAccessibilitySize {
                        VStack(alignment: .leading, spacing: Layout.spacing) {
                            captionInformation
                            HStack(spacing: Layout.spacing) { Spacer(minLength: .zero); captionActions }
                        }
                    } else {
                        HStack(alignment: .bottom, spacing: Layout.spacing) {
                            captionInformation
                            Spacer(minLength: .zero)
                            VStack(spacing: Layout.spacing) { captionActions }
                        }
                    }
                }
                .foregroundStyle(.white)
                .padding(.horizontal, Layout.horizontal)
                .padding(.bottom, UFitSpace.xl)
            }
        }.clipped()
        .ufitSheet(item: $selectedReference, onDismiss: openArticle) { item in
            VStack(alignment: .leading, spacing: Layout.captionSpacing) {
                HStack {
                    Spacer()
                    UFitButton { selectedReference = nil } label: { UFitIcon(systemName: Copy.closeIcon).frame(width: Layout.avatar, height: Layout.avatar) }
                        .accessibilityLabel(Copy.close)
                }
                ScrollView {
                    VStack(alignment: .leading, spacing: Layout.captionSpacing) {
                        UFitOutfitReferenceContent(item: item)
                        UFitButton { pendingArticleID = item.id; selectedReference = nil } label: { Text(item.productID == nil ? Copy.piece : Copy.article).frame(maxWidth: .infinity) }.ufitButtonStyle(.primary)
                    }
                }

            }.padding(Layout.horizontal).foregroundStyle(Color.ufitInk).tint(Color.ufitInk)
                .presentationDetents(typeSize.isAccessibilitySize ? [.large] : [.medium, .large]).presentationDragIndicator(.hidden)
        }
    }

    private var captionInformation: some View {
        VStack(alignment: .leading, spacing: Layout.captionSpacing) {
            if outfit.author != nil { UFitButton(action: onAuthorTap) { author }.ufitButtonStyle(.text) }
            else { author }
            UFitButton(action: onOutfitTap) {
                Text(outfit.title).ufitFont(size: Layout.title, weight: .medium).multilineTextAlignment(.leading).lineLimit(Layout.titleLines)
            }.ufitButtonStyle(.text).accessibilityLabel(outfit.title)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
    @ViewBuilder private var captionActions: some View {
        UFitButton { showingPieces.toggle() } label: {
            CircularIconButton(systemImage: Copy.bag, accessibilityLabel: outfit.products.isEmpty ? Copy.empty : (showingPieces ? Copy.hide : Copy.pieces))
        }.ufitButtonStyle(.text).disabled(outfit.products.isEmpty)
            .opacity(outfit.products.isEmpty ? Layout.unavailableOpacity : Layout.availableOpacity)
        UFitButton(action: onLike) {
            if savedState.isBusy { UFitLoading().foregroundStyle(.white).frame(width: UFitControlSize.circularAction, height: UFitControlSize.circularAction) }
            else { CircularIconButton(systemImage: savedState.symbol, accessibilityLabel: savedState.actionLabel) }
        }.ufitButtonStyle(.text).environment(\.ufitButtonIsBusy, savedState.isBusy).disabled(savedState.isBusy)
            .accessibilityLabel(savedState.actionLabel)
    }

    private var selectedPhoto: UFitOutfitGalleryPhoto? {
        outfit.photos.first(where: { $0.id == selectedPhotoID }) ?? outfit.photos.first
    }
    private func openArticle() {
        guard let id = pendingArticleID else { return }
        pendingArticleID = nil
        onItemTap(id)
    }
    private var ribbon: some View {
        UFitOutfitPiecesRibbon(items: outfit.products, onSelect: { selectedReference = $0 })
    }
    private var photoSelection: Binding<String?> {
        Binding(get: { selectedPhoto?.id }, set: { selectedPhotoID = $0 })
    }
    private var photoIndicators: some View {
        UFitPhotoPageControl(count: outfit.photos.count, selection: Binding(get: {
            outfit.photos.firstIndex(where: { $0.id == selectedPhoto?.id }) ?? .zero
        }, set: { index in if outfit.photos.indices.contains(index) { selectedPhotoID = outfit.photos[index].id } }), tint: .white)
    }

    private var author: some View {
        HStack(spacing: Layout.captionSpacing) {
            Group {
                if let avatar = outfit.author?.avatarUrl { FashionImage(source: avatar) }
                else { Text(outfit.creatorAvatar).ufitFont(size: Layout.initials, weight: .semibold).frame(maxWidth: .infinity, maxHeight: .infinity).background(.white.opacity(Layout.avatarOpacity)) }
            }.frame(width: Layout.avatar, height: Layout.avatar).clipShape(Circle()).accessibilityHidden(true)
            Text(outfit.creator).font(UFitTypography.body.weight(.medium))
        }
    }
}
