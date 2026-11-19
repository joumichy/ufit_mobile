import SwiftUI

struct UFitPinnedPhotoContent: View {
    let source: String?
    var previewData: Data? = nil
    let pins: [UFitPhotoPinPresentation]
    var contentMode: ContentMode = .fill
    var surface: UFitPhotoSurface = .dark
    let onPin: (String) -> Void
    var onPlace: ((Int, Int) -> Void)? = nil
    var selectedPinID: String? = nil
    var onMovePin: ((String, Int, Int) -> Void)? = nil
    var onRemovePin: ((String) -> Void)? = nil
    var renewSource: (() async throws -> String)? = nil
    var showsRetryLabel = true
    var imageAccessibilityLabel: String? = nil
    var onImageSize: ((CGSize) -> Void)? = nil
    @State private var image: UIImage?
    @State private var failed = false
    @State private var reload = UUID()
    private enum Copy {
        static let retry = String(localized: "Recharger la photo")
        static let image = String(localized: "Photo de la tenue")
        static let place = String(localized: "Touchez la photo pour placer la pièce sélectionnée")
        static let retryIcon = "arrow.clockwise"
        static let left = String(localized: "Déplacer à gauche")
        static let right = String(localized: "Déplacer à droite")
        static let up = String(localized: "Déplacer vers le haut")
        static let down = String(localized: "Déplacer vers le bas")
        static let remove = String(localized: "Retirer le repère")
        static let move = String(localized: "Faites glisser ce repère pour le déplacer.")
        static let center = String(localized: "Placer au centre de la photo")
        static func position(_ x: Int, _ y: Int) -> String { String(localized: "\(x) % depuis la gauche, \(y) % depuis le haut") }
    }
    private enum Layout {
        static let touch: CGFloat = UFitControlSize.touch; static let dot: CGFloat = 32; static let line: CGFloat = 1.5
        static let centerDivisor: CGFloat = 2
        static let shadow: CGFloat = 4; static let shade = 0.45; static let minimum: CGFloat = 1
        static let dragDistance: CGFloat = 3
        static let accessibilityStep = UFitOutfitPin.coordinateMax / 20
        static let percent = UFitOutfitPin.coordinateMax / 100
    }
    private enum Space { static let photo = "UFitPinnedPhoto" }
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                surface.background
                if let image {
                    let rect = imageRect(image.size, viewport: geometry.size)
                    Image(uiImage: image).resizable().frame(width: rect.width, height: rect.height).position(x: rect.midX, y: rect.midY)
                        .accessibilityLabel(imageAccessibilityLabel ?? Copy.image)
                    if onPlace != nil {
                        Color.clear.contentShape(Rectangle()).onTapGesture { point in
                            guard rect.contains(point) else { return }
                            let coordinates = coordinates(point, in: rect)
                            onPlace?(coordinates.x, coordinates.y)
                        }.accessibilityElement().accessibilityLabel(Copy.place)
                            .accessibilityAddTraits(.isButton)
                            .accessibilityAction(named: Text(Copy.center)) {
                                onPlace?(UFitOutfitPin.coordinateMax / 2, UFitOutfitPin.coordinateMax / 2)
                            }
                    }
                    ForEach(pins) { pin in
                        let x = rect.minX + CGFloat(pin.x) / CGFloat(UFitOutfitPin.coordinateMax) * rect.width
                        let y = rect.minY + CGFloat(pin.y) / CGFloat(UFitOutfitPin.coordinateMax) * rect.height
                        if x >= .zero && x <= geometry.size.width && y >= .zero && y <= geometry.size.height {
                            pinControl(pin, rect: rect).position(x: x, y: y)
                        }
                    }
                } else if failed {
                    UFitButton { reload = UUID() } label: {
                        if showsRetryLabel { Label(Copy.retry, systemImage: Copy.retryIcon).padding(UFitSpace.md) }
                        else { UFitIcon(systemName: Copy.retryIcon).font(UFitTypography.icon).frame(width: Layout.touch, height: Layout.touch) }
                    }.ufitButtonStyle(.text).foregroundStyle(surface.foreground).accessibilityLabel(Copy.retry)
                } else { UFitLoading().foregroundStyle(surface.foreground) }
            }.coordinateSpace(name: Space.photo).clipped()
        }.task(id: loadIdentity) { await load() }
    }
    @ViewBuilder private func pinControl(_ pin: UFitPhotoPinPresentation, rect: CGRect) -> some View {
        let control = UFitButton { onPin(pin.id) } label: {
            UFitOutfitItemIcon(type: pin.itemType).frame(width: Layout.dot, height: Layout.dot)
                .foregroundStyle(selectedPinID == pin.id ? Color.ufitInk : .white)
                .background(selectedPinID == pin.id ? Color.white : Color.black.opacity(Layout.shade), in: Circle())
                .overlay { Circle().stroke(.white, lineWidth: Layout.line) }
                .frame(width: Layout.touch, height: Layout.touch)
        }.ufitButtonStyle(.text).shadow(radius: Layout.shadow).accessibilityLabel(pin.label)
            .accessibilityAddTraits(selectedPinID == pin.id ? .isSelected : [])
        if let onMovePin {
            control.highPriorityGesture(DragGesture(minimumDistance: Layout.dragDistance, coordinateSpace: .named(Space.photo))
                .onChanged { value in
                    onPin(pin.id)
                    let point = coordinates(value.location, in: rect)
                    onMovePin(pin.id, point.x, point.y)
                })
                .accessibilityHint(Copy.move)
                .accessibilityValue(Copy.position(pin.x / Layout.percent, pin.y / Layout.percent))
                .accessibilityAction(named: Text(Copy.left)) { move(pin, x: -Layout.accessibilityStep) }
                .accessibilityAction(named: Text(Copy.right)) { move(pin, x: Layout.accessibilityStep) }
                .accessibilityAction(named: Text(Copy.up)) { move(pin, y: -Layout.accessibilityStep) }
                .accessibilityAction(named: Text(Copy.down)) { move(pin, y: Layout.accessibilityStep) }
                .accessibilityAction(named: Text(Copy.remove)) { onRemovePin?(pin.id) }
        } else { control }
    }
    private func move(_ pin: UFitPhotoPinPresentation, x: Int = .zero, y: Int = .zero) {
        onPin(pin.id)
        onMovePin?(pin.id, min(UFitOutfitPin.coordinateMax, max(.zero, pin.x + x)), min(UFitOutfitPin.coordinateMax, max(.zero, pin.y + y)))
    }
    private func coordinates(_ point: CGPoint, in rect: CGRect) -> (x: Int, y: Int) {
        let maximum = CGFloat(UFitOutfitPin.coordinateMax)
        return (Int((min(maximum, max(.zero, (point.x - rect.minX) / rect.width * maximum))).rounded()),
                Int((min(maximum, max(.zero, (point.y - rect.minY) / rect.height * maximum))).rounded()))
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
        if let previewData, let value = UIImage(data: previewData) { receiveImage(value); return }
        guard let source else { failed = true; return }
        if let value = UIImage(named: source) { receiveImage(value); return }
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
            receiveImage(loaded)
        } catch { if !Task.isCancelled { failed = true } }
    }
    @MainActor private func receiveImage(_ value: UIImage) {
        image = value
        onImageSize?(value.size)
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
