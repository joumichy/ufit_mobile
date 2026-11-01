import SwiftUI

struct UFitOutfitGalleryContent: View {
    let photos: [UFitOutfitGalleryPhoto]
    var contentMode: ContentMode = .fill
    var imageHeight: CGFloat = Layout.hero
    var renewPhotoSource: ((String) async throws -> String)? = nil
    @State private var selectedPosition: Int?
    private enum Copy {
        static let empty = String(localized: "Aucune photo")
        static func page(_ number: Int, count: Int) -> String { String(localized: "Photo \(number) sur \(count)") }
    }
    private enum Layout {
        static let hero: CGFloat = 340; static let step = 1
    }
    private enum Icon { static let photo = "photo" }
    private var pageIndex: Int { photos.firstIndex(where: { $0.position == selectedPosition }) ?? .zero }
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
                                UFitPinnedPhotoContent(source: photo.url, pins: [], contentMode: contentMode, onPin: {_ in},
                                    renewSource: renewPhotoSource.map { renew in { () async throws -> String in try await renew(photo.id) } })
                            } else { FashionImage(source: photo.url).clipped() }
                        }
                            .accessibilityLabel(Copy.page((photos.firstIndex(where: { $0.id == photo.id }) ?? .zero) + Layout.step, count: photos.count))
                            .tag(Optional(photo.position))
                    }
                }.tabViewStyle(.page(indexDisplayMode: .never)).frame(height: imageHeight)
                if photos.count > Layout.step {
                    UFitPhotoPageControl(count: photos.count, selection: Binding(get: { pageIndex }, set: { index in
                        if photos.indices.contains(index) { selectedPosition = photos[index].position }
                    }), tint: UIColor(Color.ufitInk))

                }
            }
        }.foregroundStyle(Color.ufitInk).tint(Color.ufitInk).background(Color.ufitCanvas)
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
