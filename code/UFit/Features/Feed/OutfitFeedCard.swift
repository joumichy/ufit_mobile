import SwiftUI

struct OutfitFeedCard: View {
    let outfit: Outfit
    let isLiked: Bool
    let onLike: () -> Void
    let onOutfitTap: () -> Void
    let onAuthorTap: () -> Void
    var isSaving = false

    private enum Copy {
        static let save = String(localized: "Sauvegarder la tenue")
        static let unsave = String(localized: "Retirer des favoris")
        static let saving = String(localized: "Enregistrement")
        static let pieces = String(localized: "Voir les pièces")
        static let bookmark = "bookmark"
        static let savedBookmark = "bookmark.fill"
        static let bag = "bag"
    }
    private enum Layout {
        static let spacing: CGFloat = 20
        static let captionSpacing: CGFloat = 14
        static let horizontal: CGFloat = 24
        static let bottom: CGFloat = 132
        static let avatar: CGFloat = 44
        static let title: CGFloat = 26
        static let initials: CGFloat = 14
        static let overlayOpacity = 0.72
        static let avatarOpacity = 0.18
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                FashionImage(source: outfit.imageName)
                    .frame(width: proxy.size.width, height: proxy.size.height).clipped()
                LinearGradient(colors: [.clear, .clear, .black.opacity(Layout.overlayOpacity)], startPoint: .top, endPoint: .bottom)
                HStack(alignment: .bottom, spacing: Layout.spacing) {
                    VStack(alignment: .leading, spacing: Layout.captionSpacing) {
                        if outfit.author != nil {
                            Button(action: onAuthorTap) { author }.buttonStyle(.plain)
                        } else { author }
                        Button(action: onOutfitTap) {
                            Text(outfit.title).font(.system(size: Layout.title, weight: .medium)).multilineTextAlignment(.leading)
                        }.buttonStyle(.plain)
                    }
                    Spacer(minLength: .zero)
                    VStack(spacing: Layout.spacing) {
                        Button(action: onOutfitTap) {
                            CircularIconButton(systemImage: Copy.bag, accessibilityLabel: Copy.pieces)
                        }.buttonStyle(.plain)
                        Button(action: onLike) {
                            if isSaving {
                                ProgressView().tint(.white).frame(width: Layout.avatar, height: Layout.avatar)
                            } else {
                                CircularIconButton(systemImage: isLiked ? Copy.savedBookmark : Copy.bookmark, accessibilityLabel: isLiked ? Copy.unsave : Copy.save)
                            }
                        }
                        .buttonStyle(.plain).disabled(isSaving)
                        .accessibilityLabel(isSaving ? Copy.saving : (isLiked ? Copy.unsave : Copy.save))
                    }
                }
                .foregroundStyle(.white)
                .padding(.horizontal, Layout.horizontal)
                .padding(.bottom, Layout.bottom)
            }
        }.clipped()
    }

    private var author: some View {
        HStack(spacing: Layout.captionSpacing) {
            Group {
                if let avatar = outfit.author?.avatarUrl { FashionImage(source: avatar) }
                else { Text(outfit.creatorAvatar).font(.system(size: Layout.initials, weight: .semibold)).frame(maxWidth: .infinity, maxHeight: .infinity).background(.white.opacity(Layout.avatarOpacity)) }
            }.frame(width: Layout.avatar, height: Layout.avatar).clipShape(Circle()).accessibilityHidden(true)
            Text(outfit.creator).font(.body.weight(.medium))
        }
    }
}
