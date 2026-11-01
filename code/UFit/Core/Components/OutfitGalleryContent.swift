import SwiftUI

struct UFitOutfitGalleryContent: View {
    let photos: [UFitOutfitGalleryPhoto]
    @State private var selectedPosition: Int?
    private enum Copy {
        static let previous = String(localized: "Photo précédente")
        static let next = String(localized: "Photo suivante")
        static let empty = String(localized: "Aucune photo")
        static func page(_ number: Int, count: Int) -> String { String(localized: "Photo \(number) sur \(count)") }
    }
    private enum Layout {
        static let hero: CGFloat = 340; static let touch: CGFloat = 44; static let inset: CGFloat = 24; static let step = 1
        static let disabledOpacity = 0.3; static let enabledOpacity = 1.0
    }
    private enum Icon { static let previous = "chevron.left"; static let next = "chevron.right"; static let photo = "photo" }
    private var pageIndex: Int { photos.firstIndex(where: { $0.position == selectedPosition }) ?? .zero }
    private var selection: Binding<Int?> {
        Binding(get: { photos.isEmpty ? nil : photos[pageIndex].position }, set: { position in
            if photos.contains(where: { $0.position == position }) { selectedPosition = position }
        })
    }
    var body: some View {
        VStack(spacing: .zero) {
            if photos.isEmpty {
                Color.ufitBackground.overlay { Label(Copy.empty, systemImage: Icon.photo).foregroundStyle(Color.ufitMuted) }.frame(height: Layout.hero)
            } else {
                TabView(selection: selection) {
                    ForEach(photos) { photo in
                        FashionImage(source: photo.url).clipped()
                            .accessibilityLabel(Copy.page((photos.firstIndex(where: { $0.id == photo.id }) ?? .zero) + Layout.step, count: photos.count))
                            .tag(Optional(photo.position))
                    }
                }.tabViewStyle(.page(indexDisplayMode: .never)).frame(height: Layout.hero)
                if photos.count > Layout.step {
                    HStack {
                        Button { move(-Layout.step) } label: { Image(systemName: Icon.previous).frame(width: Layout.touch, height: Layout.touch) }
                            .accessibilityLabel(Copy.previous).disabled(pageIndex == .zero).opacity(pageIndex == .zero ? Layout.disabledOpacity : Layout.enabledOpacity)
                        Spacer()
                        Text(Copy.page(pageIndex + Layout.step, count: photos.count)).font(.caption).monospacedDigit()
                        Spacer()
                        Button { move(Layout.step) } label: { Image(systemName: Icon.next).frame(width: Layout.touch, height: Layout.touch) }
                            .accessibilityLabel(Copy.next).disabled(pageIndex == photos.count - Layout.step)
                            .opacity(pageIndex == photos.count - Layout.step ? Layout.disabledOpacity : Layout.enabledOpacity)
                    }.padding(.horizontal, Layout.inset)
                }
            }
        }.foregroundStyle(Color.ufitInk).tint(Color.ufitInk).background(Color.white)
    }
    private func move(_ step: Int) {
        let next = pageIndex + step
        if photos.indices.contains(next) { selectedPosition = photos[next].position }
    }
}
