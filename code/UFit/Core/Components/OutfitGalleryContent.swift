import SwiftUI

struct UFitOutfitGalleryContent: View {
    let photos: [UFitOutfitGalleryPhoto]
    var contentMode: ContentMode = .fill
    var imageHeight: CGFloat = Layout.hero
    var surface: UFitPhotoSurface = .dark
    /// Preserve the full image and use imageHeight only as its upper height limit.
    var adaptsToImage = false
    var photoAccessibilityLabel: String? = nil
    var renewPhotoSource: ((String) async throws -> String)? = nil
    @State private var selectedPosition: Int?
    @State private var contentWidth: CGFloat = .zero
    @State private var photoSizes: [String: CGSize] = [:]
    private enum Copy {
        static let empty = String(localized: "Aucune photo")
        static func page(_ number: Int, count: Int) -> String { String(localized: "Photo \(number) sur \(count)") }
    }
    private enum Layout {
        static let hero: CGFloat = 340; static let step = 1
    }
    private enum Icon { static let photo = "photo" }
    private var pageIndex: Int { photos.firstIndex(where: { $0.position == selectedPosition }) ?? .zero }
    private var displayedHeight: CGFloat {
        guard adaptsToImage, contentWidth > .zero, photos.indices.contains(pageIndex),
              let size = photoSizes[photos[pageIndex].id], size.width > .zero, size.height > .zero,
              size.width.isFinite, size.height.isFinite else { return imageHeight }
        return min(imageHeight, contentWidth * size.height / size.width)
    }
    private var selection: Binding<Int?> {
        Binding(get: { photos.isEmpty ? nil : photos[pageIndex].position }, set: { position in
            if photos.contains(where: { $0.position == position }) { selectedPosition = position }
        })
    }
    var body: some View {
        VStack(spacing: .zero) {
            if photos.isEmpty {
                Color.ufitCanvas.overlay { Label(Copy.empty, systemImage: Icon.photo).foregroundStyle(Color.ufitSecondaryText) }.frame(height: imageHeight)
            } else {
                TabView(selection: selection) {
                    ForEach(photos) { photo in
                        Group {
                            if contentMode == .fit || renewPhotoSource != nil {
                                UFitPinnedPhotoContent(source: photo.url, pins: [], contentMode: contentMode, surface: surface, onPin: {_ in},
                                    renewSource: renewPhotoSource.map { renew in { () async throws -> String in try await renew(photo.id) } },
                                    onImageSize: adaptsToImage ? { photoSizes[photo.id] = $0 } : nil)
                            } else { FashionImage(source: photo.url).clipped() }
                        }
                            .accessibilityLabel(Copy.page((photos.firstIndex(where: { $0.id == photo.id }) ?? .zero) + Layout.step, count: photos.count))
                            .tag(Optional(photo.position))
                    }
                }.tabViewStyle(.page(indexDisplayMode: .never)).frame(height: displayedHeight)
                if photos.count > Layout.step {
                    UFitPhotoPageControl(count: photos.count, selection: Binding(get: { pageIndex }, set: { index in
                        if photos.indices.contains(index) { selectedPosition = photos[index].position }
                    }), tint: UIColor(Color.ufitInk), accessibilityLabel: photoAccessibilityLabel)

                }
            }
        }.background {
            GeometryReader { geometry in
                Color.clear.onAppear { receiveWidth(geometry.size.width) }
                    .onChange(of: geometry.size.width) { _, width in receiveWidth(width) }
            }
        }.foregroundStyle(Color.ufitInk).tint(Color.ufitInk).background(Color.ufitCanvas)
            .onChange(of: photos.map(\.id)) { _, ids in photoSizes = photoSizes.filter { ids.contains($0.key) } }
    }
    private func receiveWidth(_ width: CGFloat) {
        if width > .zero, width.isFinite, width != contentWidth { contentWidth = width }
    }
}

struct UFitOutfitPhotoPages: View {
    let photos: [UFitOutfitGalleryPhoto]
    @Binding var selection: String?
    let size: CGSize
    var body: some View {
        TabView(selection: $selection) {
            ForEach(photos) { photo in
                FashionImage(source: photo.url).frame(width: size.width, height: size.height).clipped().tag(Optional(photo.id))
            }
        }.tabViewStyle(.page(indexDisplayMode: .never))
    }
}
