import SwiftUI

struct UFitPinnedPhotoContent: View {
    let source: String?
    var previewData: Data? = nil
    let pins: [UFitPhotoPinPresentation]
    var contentMode: ContentMode = .fill
    let onPin: (String) -> Void
    var onPlace: ((Int, Int) -> Void)? = nil
    var renewSource: (() async throws -> String)? = nil
    @State private var image: UIImage?
    @State private var failed = false
    @State private var reload = UUID()
    private enum Copy {
        static let retry = String(localized: "Recharger la photo")
        static let image = String(localized: "Photo de la tenue")
        static let place = String(localized: "Touchez la photo pour placer la pièce sélectionnée")
        static let retryIcon = "arrow.clockwise"
    }
    private enum Layout {
        static let touch: CGFloat = 44; static let dot: CGFloat = 32; static let line: CGFloat = 1.5
        static let centerDivisor: CGFloat = 2
        static let shadow: CGFloat = 4; static let shade = 0.45; static let minimum: CGFloat = 1
    }
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black
                if let image {
                    let rect = imageRect(image.size, viewport: geometry.size)
                    Image(uiImage: image).resizable().frame(width: rect.width, height: rect.height).position(x: rect.midX, y: rect.midY)
                        .accessibilityLabel(Copy.image)
                    if onPlace != nil {
                        Color.clear.contentShape(Rectangle()).onTapGesture { point in
                            guard rect.contains(point) else { return }
                            let maximum = CGFloat(UFitOutfitPin.coordinateMax)
                            let x = Int(((point.x - rect.minX) / rect.width * maximum).rounded())
                            let y = Int(((point.y - rect.minY) / rect.height * maximum).rounded())
                            onPlace?(x, y)
                        }.accessibilityLabel(Copy.place)
                    }
                    ForEach(pins) { pin in
                        let x = rect.minX + CGFloat(pin.x) / CGFloat(UFitOutfitPin.coordinateMax) * rect.width
                        let y = rect.minY + CGFloat(pin.y) / CGFloat(UFitOutfitPin.coordinateMax) * rect.height
                        if x >= .zero && x <= geometry.size.width && y >= .zero && y <= geometry.size.height {
                            Button { onPin(pin.id) } label: {
                                UFitOutfitItemIcon(symbol: pin.symbol).frame(width: Layout.dot, height: Layout.dot)
                                    .background(.black.opacity(Layout.shade), in: Circle()).overlay { Circle().stroke(.white, lineWidth: Layout.line) }
                                    .frame(width: Layout.touch, height: Layout.touch)
                            }.buttonStyle(.plain).foregroundStyle(.white).shadow(radius: Layout.shadow)
                                .accessibilityLabel(pin.label).position(x: x, y: y)
                        }
                    }
                } else if failed {
                    Button { reload = UUID() } label: { Label(Copy.retry, systemImage: Copy.retryIcon).padding() }.tint(.white)
                } else { ProgressView().tint(.white) }
            }.clipped()
        }.task(id: loadIdentity) { await load() }
    }
    private var loadIdentity: String { (source ?? String()) + reload.uuidString }
    private func imageRect(_ size: CGSize, viewport: CGSize) -> CGRect {
        let width = max(size.width, Layout.minimum), height = max(size.height, Layout.minimum)
        let scale = contentMode == .fill ? max(viewport.width / width, viewport.height / height) : min(viewport.width / width, viewport.height / height)
        let fitted = CGSize(width: width * scale, height: height * scale)
        return .init(x: (viewport.width - fitted.width) / Layout.centerDivisor, y: (viewport.height - fitted.height) / Layout.centerDivisor, width: fitted.width, height: fitted.height)
    }
    @MainActor private func load() async {
        image = nil; failed = false
        if let previewData, let value = UIImage(data: previewData) { image = value; return }
        guard let source else { failed = true; return }
        if let value = UIImage(named: source) { image = value; return }
        do {
            let loaded: UIImage
            do { loaded = try await download(source) }
            catch {
                guard !Task.isCancelled, let renewSource else { throw error }
                let renewed = try await renewSource()
                try Task.checkCancellation()
                loaded = try await download(renewed)
            }
            guard !Task.isCancelled else { return }
            image = loaded
        } catch { if !Task.isCancelled { failed = true } }
    }
    private func download(_ source: String) async throws -> UIImage {
        guard let url = URL(string: source) else { throw UFitPhotoImageError.invalid }
        let (data, response) = try await URLSession.shared.data(from: url)
        try Task.checkCancellation()
        guard let http = response as? HTTPURLResponse, UFitImageHTTP.success.contains(http.statusCode), let value = UIImage(data: data) else { throw UFitPhotoImageError.invalid }
        return value
    }
}
private enum UFitImageHTTP { static let success = 200..<300 }

private enum UFitPhotoImageError: Error { case invalid }
