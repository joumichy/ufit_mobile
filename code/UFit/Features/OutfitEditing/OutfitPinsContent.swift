import SwiftUI

struct UFitOutfitPinsContent: View {
    @Binding var photo: UFitOutfitPhotoDraft
    let pieces: [UFitOutfitPieceDraft]
    let onClose: () -> Void
    var renewSource: (() async throws -> String)? = nil
    @State private var selectedID: UUID?
    private enum Copy {
        static let title = String(localized: "Placer les pièces")
        static let place = String(localized: "Touchez son emplacement sur la photo.")
        static let move = String(localized: "Glissez le repère pour l’ajuster.")
        static let choose = String(localized: "Choisissez une pièce à placer.")
        static let empty = String(localized: "Ajoutez d’abord une pièce à la tenue.")
        static let remove = String(localized: "Retirer le repère")
        static let placed = String(localized: "Repère placé")
        static let unplaced = String(localized: "À placer")
    }
    private enum Icon { static let remove = "trash"; static let placed = "checkmark" }
    private enum Layout {
        static let icon: CGFloat = 24
        static let choice: CGFloat = 56
        static let badge: CGFloat = 12
    }
    private var selectedPiece: UFitOutfitPieceDraft? { pieces.first { $0.id == selectedID } }
    private var hasSelectedPin: Bool { photo.pins.contains { $0.pieceID == selectedID } }
    private var annotations: [UFitPhotoPinPresentation] {
        photo.pins.compactMap { pin in
            guard let piece = pieces.first(where: { $0.id == pin.pieceID }) else { return nil }
            return .init(id: pin.pieceID.uuidString, label: piece.title, itemType: piece.type, x: pin.x, y: pin.y)
        }
    }
    var body: some View {
        VStack(spacing: .zero) {
            DetailHeader(title: Copy.title, onBack: onClose)
            UFitPinnedPhotoContent(source: photo.source, previewData: photo.previewData, pins: annotations, contentMode: .fit,
                onPin: { selectedID = UUID(uuidString: $0) }, onPlace: selectedPiece == nil ? nil : place,
                selectedPinID: selectedID?.uuidString, onMovePin: move, onRemovePin: remove, renewSource: renewSource)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            controls
        }.foregroundStyle(Color.ufitInk).background(Color.ufitCanvas)
            .onAppear { if selectedID == nil { selectedID = pieces.first?.id } }
            .onChange(of: pieces.map(\.id)) { _, ids in
                if let selectedID, !ids.contains(selectedID) { self.selectedID = ids.first }
            }
    }
    private var controls: some View {
        VStack(alignment: .leading, spacing: UFitSpace.xs) {
            HStack(alignment: .center, spacing: UFitSpace.sm) {
                VStack(alignment: .leading, spacing: UFitSpace.xxs) {
                    if let selectedPiece {
                        Text(selectedPiece.title).font(UFitTypography.subheadline.weight(.medium))
                            .fixedSize(horizontal: false, vertical: true)
                        Text(hasSelectedPin ? Copy.move : Copy.place).font(UFitTypography.caption).foregroundStyle(Color.ufitSecondaryText)
                    } else {
                        Text(pieces.isEmpty ? Copy.empty : Copy.choose).font(UFitTypography.subheadline)
                            .foregroundStyle(Color.ufitSecondaryText)
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
                if hasSelectedPin, let selectedID {
                    UFitButton { remove(selectedID.uuidString) } label: {
                        UFitIcon(systemName: Icon.remove).frame(width: UFitControlSize.touch, height: UFitControlSize.touch)
                    }.ufitButtonStyle(.text).accessibilityLabel(Copy.remove)
                }
            }.frame(minHeight: UFitControlSize.touch).padding(.horizontal, UFitSpace.page)
            if !pieces.isEmpty { piecePicker }
        }.padding(.top, UFitSpace.sm).padding(.bottom, UFitSpace.sm)
            .background(Color.ufitCanvas).overlay(alignment: .top) { Divider() }
    }
    private var piecePicker: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                HStack(spacing: UFitSpace.sm) {
                    ForEach(pieces) { piece in
                        UFitButton { selectedID = piece.id } label: {
                            UFitOutfitItemIcon(type: piece.type).frame(width: Layout.icon, height: Layout.icon)
                                .frame(width: Layout.choice, height: Layout.choice)
                                .background(selectedID == piece.id ? Color.ufitSecondary : Color.ufitCanvas,
                                    in: RoundedRectangle(cornerRadius: UFitRadius.action))
                                .overlay { RoundedRectangle(cornerRadius: UFitRadius.action)
                                    .strokeBorder(selectedID == piece.id ? Color.ufitInk : Color.ufitBorder,
                                        lineWidth: selectedID == piece.id ? UFitStroke.selected : UFitStroke.control) }
                                .overlay(alignment: .topTrailing) {
                                    if photo.pins.contains(where: { $0.pieceID == piece.id }) {
                                        UFitIcon(systemName: Icon.placed).font(UFitTypography.caption2)
                                            .frame(width: Layout.badge, height: Layout.badge)
                                            .padding(UFitSpace.xxs).background(Color.ufitCanvas, in: Circle())
                                            .accessibilityHidden(true)
                                    }
                                }
                        }.ufitButtonStyle(.text).accessibilityLabel(piece.title)
                            .accessibilityValue(photo.pins.contains(where: { $0.pieceID == piece.id }) ? Copy.placed : Copy.unplaced)
                            .accessibilityRemoveTraits(selectedID == piece.id ? [] : .isSelected)
                            .accessibilityAddTraits(selectedID == piece.id ? .isSelected : [])
                            .id(piece.id)
                    }
                }.padding(.horizontal, UFitSpace.page).padding(.vertical, UFitSpace.xxs)
            }.scrollIndicators(.hidden)
                .onChange(of: selectedID) { _, value in if let value { proxy.scrollTo(value, anchor: .center) } }
        }
    }
    private func place(_ x: Int, _ y: Int) {
        guard let selectedID else { return }
        move(selectedID.uuidString, x, y)
    }
    private func move(_ id: String, _ x: Int, _ y: Int) {
        guard let pieceID = UUID(uuidString: id), pieces.contains(where: { $0.id == pieceID }) else { return }
        if let index = photo.pins.firstIndex(where: { $0.pieceID == pieceID }) {
            photo.pins[index].x = x; photo.pins[index].y = y
        } else { photo.pins.append(.init(pieceID: pieceID, x: x, y: y)) }
    }
    private func remove(_ id: String) {
        guard let pieceID = UUID(uuidString: id) else { return }
        photo.pins.removeAll { $0.pieceID == pieceID }
    }
}
