import SwiftUI

struct UFitOutfitPinsContent: View {
    @Binding var photo: UFitOutfitPhotoDraft
    let pieces: [UFitOutfitPieceDraft]
    let onClose: () -> Void
    var renewSource: (() async throws -> String)? = nil
    @State private var selectedID: UUID?
    private enum Copy {
        static let title = String(localized: "Repères sur la photo")
        static let piece = String(localized: "Pièce à placer")
        static let choose = String(localized: "Choisir une pièce")
        static let place = String(localized: "Touchez la photo à l’emplacement de cette pièce.")
        static let empty = String(localized: "Ajoutez d’abord une pièce à la tenue.")
        static let remove = String(localized: "Retirer le repère")
        static let horizontal = String(localized: "Position horizontale")
        static let vertical = String(localized: "Position verticale")
        static let done = String(localized: "Terminé")
    }
    private enum Layout { static let gap: CGFloat = 16; static let photo: CGFloat = 420; static let touch: CGFloat = 44; static let step = 100.0 }
    private var annotations: [UFitPhotoPinPresentation] {
        photo.pins.compactMap { pin in
            guard let piece = pieces.first(where: { $0.id == pin.pieceID }) else { return nil }
            return .init(id: pin.pieceID.uuidString, label: piece.title, symbol: piece.type.symbol, x: pin.x, y: pin.y)
        }
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Layout.gap) {
                    if pieces.isEmpty { Text(Copy.empty).foregroundStyle(Color.ufitMuted) }
                    else {
                        piecePicker
                        if selectedID != nil { Text(Copy.place).font(.callout).foregroundStyle(Color.ufitMuted) }
                    }
                    UFitPinnedPhotoContent(source: photo.source, previewData: photo.previewData, pins: annotations, contentMode: .fit,
                        onPin: { selectedID = UUID(uuidString: $0) }, onPlace: selectedID == nil ? nil : place, renewSource: renewSource)
                        .frame(height: Layout.photo)
                    if let selectedID, let pin = photo.pins.first(where: { $0.pieceID == selectedID }) {
                        Text(pieces.first(where: { $0.id == selectedID })?.title ?? String()).font(.headline)
                        coordinate(Copy.horizontal, value: pin.x, keyPath: \.x)
                        coordinate(Copy.vertical, value: pin.y, keyPath: \.y)
                        Button(Copy.remove, role: .destructive) { photo.pins.removeAll { $0.pieceID == selectedID } }.frame(minHeight: Layout.touch)
                    }
                    ForEach(photo.pins.filter { $0.pieceID != selectedID }) { pin in
                        if let piece = pieces.first(where: { $0.id == pin.pieceID }) {
                            Button { selectedID = pin.pieceID } label: { HStack { UFitOutfitItemIcon(symbol: piece.type.symbol); Text(piece.title) }.frame(minHeight: Layout.touch) }
                        }
                    }
                }.padding(Layout.gap)
            }.navigationTitle(Copy.title).navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button(Copy.done, action: onClose) } }
                .foregroundStyle(Color.ufitInk).tint(Color.ufitInk).background(Color.white)
        }
    }
    private var piecePicker: some View {
                        Picker(Copy.piece, selection: $selectedID) {
                            Text(Copy.choose).tag(Optional<UUID>.none)
                            ForEach(pieces) { piece in HStack { UFitOutfitItemIcon(symbol: piece.type.symbol); Text(piece.title) }.tag(Optional(piece.id)) }
                        }.pickerStyle(.menu).frame(minHeight: Layout.touch)
    }
    private func place(_ x: Int, _ y: Int) {
        guard let selectedID else { return }
        photo.pins.removeAll { $0.pieceID == selectedID }
        photo.pins.append(.init(pieceID: selectedID, x: x, y: y))
    }
    private func coordinate(_ title: String, value: Int, keyPath: WritableKeyPath<UFitOutfitDraftPin, Int>) -> some View {
        VStack(alignment: .leading) {
            Text(title).font(.caption)
            Slider(value: Binding(get: { Double(photo.pins.first(where: { $0.pieceID == selectedID })?[keyPath: keyPath] ?? value) }, set: { next in
                guard let index = photo.pins.firstIndex(where: { $0.pieceID == selectedID }) else { return }
                photo.pins[index][keyPath: keyPath] = Int(next)
            }), in: .zero...Double(UFitOutfitPin.coordinateMax), step: Layout.step).accessibilityLabel(title)
        }
    }
}
