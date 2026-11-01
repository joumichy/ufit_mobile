import SwiftUI

struct OutfitFeedCard: View {
    let outfit: Outfit
    let isLiked: Bool
    let onLike: () -> Void
    let onOutfitTap: () -> Void
    let onAuthorTap: () -> Void
    var isSaving = false
    var onItemTap: (String) -> Void = {_ in}
    @Binding var showingPieces: Bool
    @State private var pendingArticleID: String?
    @State private var selectedReference: OutfitProduct?
    @Binding var selectedPhotoID: String?

    private enum Copy {
        static let save = String(localized: "Sauvegarder la tenue")
        static let unsave = String(localized: "Retirer des favoris")
        static let saving = String(localized: "Enregistrement")
        static let pieces = String(localized: "Voir les pièces")
        static let hide = String(localized: "Masquer les pièces")
        static let empty = String(localized: "Aucune pièce associée")
        static let piece = String(localized: "Voir la pièce")
        static let article = String(localized: "Voir l’article")
        static let close = String(localized: "Fermer la référence")
        static let closeIcon = "xmark"
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
        static let unavailableOpacity = 0.4; static let availableOpacity = 1.0
        static let ribbonWidth: CGFloat = 50; static let ribbonHeight: CGFloat = 320; static let ribbonBottom: CGFloat = 265
        static let ribbonGap: CGFloat = 11;
        static let referenceImage: CGFloat = 92
        static let dotsBottom: CGFloat = 88; static let step = 1
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                if outfit.photos.isEmpty {
                    FashionImage(source: outfit.imageName).frame(width: proxy.size.width, height: proxy.size.height).clipped()
                } else {
                    TabView(selection: photoSelection) {
                        ForEach(outfit.photos) { photo in
                            FashionImage(source: photo.url)
                                .frame(width: proxy.size.width, height: proxy.size.height).clipped().tag(Optional(photo.id))
                        }
                    }.tabViewStyle(.page(indexDisplayMode: .never))
                }
                LinearGradient(colors: [.clear, .clear, .black.opacity(Layout.overlayOpacity)], startPoint: .top, endPoint: .bottom).allowsHitTesting(false)
                if outfit.photos.count > Layout.step {
                    photoIndicators.padding(.bottom, Layout.dotsBottom)
                }
                if showingPieces && !outfit.products.isEmpty {
                    VStack { Spacer(); HStack { Spacer(); ribbon }.padding(.horizontal, Layout.horizontal) }
                        .padding(.bottom, Layout.ribbonBottom)
                }
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
                        Button { showingPieces.toggle() } label: {
                            CircularIconButton(systemImage: Copy.bag, accessibilityLabel: outfit.products.isEmpty ? Copy.empty : (showingPieces ? Copy.hide : Copy.pieces))
                        }.buttonStyle(.plain).disabled(outfit.products.isEmpty)
                            .opacity(outfit.products.isEmpty ? Layout.unavailableOpacity : Layout.availableOpacity)
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
        .sheet(item: $selectedReference, onDismiss: openArticle) { item in
            VStack(alignment: .leading, spacing: Layout.captionSpacing) {
                HStack {
                    Spacer()
                    Button { selectedReference = nil } label: { Image(systemName: Copy.closeIcon).frame(width: Layout.avatar, height: Layout.avatar) }
                        .accessibilityLabel(Copy.close)
                }
                HStack(spacing: Layout.spacing) {
                    if let image = item.image { FashionImage(source: image).frame(width: Layout.referenceImage, height: Layout.referenceImage).clipped() }
                    VStack(alignment: .leading, spacing: Layout.captionSpacing) {
                        if let brand = item.brandName { Text(brand).font(.caption).foregroundStyle(Color.ufitMuted) }
                        Text(item.name).font(.title2)
                        if let price = item.price { Text(price).font(.subheadline) }
                    }
                }
                Button { pendingArticleID = item.id; selectedReference = nil } label: { Text(item.productID == nil ? Copy.piece : Copy.article).frame(maxWidth: .infinity) }.buttonStyle(PrimaryButtonStyle())
                Spacer(minLength: .zero)
            }.padding(Layout.horizontal).foregroundStyle(Color.ufitInk).tint(Color.ufitInk)
                .presentationDetents([.medium, .large]).presentationDragIndicator(.visible)
        }
    }

    private var selectedPhoto: UFitOutfitGalleryPhoto? {
        outfit.photos.first(where: { $0.id == selectedPhotoID }) ?? outfit.photos.first
    }
    private func openArticle() {
        guard let id = pendingArticleID else { return }
        pendingArticleID = nil
        onItemTap(id)
    }
    private func selectReference(_ id: String) {
        selectedReference = outfit.products.first(where: { $0.id == id })
    }
    private var ribbon: some View {
        let count = max(outfit.products.count, Layout.step)
        let height = min(CGFloat(count) * Layout.ribbonWidth + CGFloat(count - Layout.step) * Layout.ribbonGap, Layout.ribbonHeight)
        return ScrollView(.vertical) {
            VStack(spacing: Layout.ribbonGap) {
                ForEach(outfit.products) { item in
                    Button { selectReference(item.id) } label: {
                        UFitOutfitItemIcon(symbol: item.systemImage).frame(width: Layout.ribbonWidth, height: Layout.ribbonWidth)
                            .background(.white.opacity(Layout.avatarOpacity), in: Circle()).accessibilityLabel(item.name)
                    }.buttonStyle(.plain)
                }
            }
        }.scrollIndicators(.hidden).frame(width: Layout.ribbonWidth, height: height).foregroundStyle(.white)
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
                else { Text(outfit.creatorAvatar).font(.system(size: Layout.initials, weight: .semibold)).frame(maxWidth: .infinity, maxHeight: .infinity).background(.white.opacity(Layout.avatarOpacity)) }
            }.frame(width: Layout.avatar, height: Layout.avatar).clipShape(Circle()).accessibilityHidden(true)
            Text(outfit.creator).font(.body.weight(.medium))
        }
    }
}
