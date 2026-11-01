import SwiftUI

struct UFitOutfitPiecesContent: View {
    @Binding var pieces: [UFitOutfitPieceDraft]
    let error: String?
    let onSelectProduct: () -> Void
    private enum Copy {
        static let title = String(localized: "Les pièces"); static let product = String(localized: "Ajouter un produit")
        static let inspiration = String(localized: "Ajouter une pièce d’inspiration"); static let empty = String(localized: "Aucune pièce")
        static let label = String(localized: "Nom de la pièce")
        static let type = String(localized: "Type de pièce"); static let required = String(localized: "Essentielle à cette tenue")
        static let note = String(localized: "Note de style (facultatif)"); static let replace = String(localized: "Remplacer par une inspiration")
        static let notForSale = String(localized: "Inspiration · non vendue sur Ufit")
        static let unavailable = String(localized: "Produit indisponible")
        static let up = String(localized: "Déplacer la pièce avant"); static let down = String(localized: "Déplacer la pièce après"); static let remove = String(localized: "Retirer la pièce")
    }
    private enum Layout { static let gap: CGFloat = 16; static let small: CGFloat = 8; static let touch: CGFloat = 44; static let thumbnail: CGFloat = 68; static let radius: CGFloat = 12 }
    private enum Icon { static let up = "arrow.up"; static let down = "arrow.down"; static let photo = "tshirt" }
    var body: some View {
        VStack(alignment: .leading, spacing: Layout.gap) {
            Text(Copy.title).font(.title2.weight(.medium))
            if pieces.isEmpty { Text(Copy.empty).font(.callout).foregroundStyle(Color.ufitMuted) }
            ForEach(pieces) { snapshot in
                PieceRow(piece: binding(for: snapshot), canMoveBefore: pieces.first?.id != snapshot.id,
                    canMoveAfter: pieces.last?.id != snapshot.id,
                    onBefore: { move(snapshot.id, step: -UFitOutfitInput.positionStep) },
                    onAfter: { move(snapshot.id, step: UFitOutfitInput.positionStep) },
                    onRemove: { pieces.removeAll { $0.id == snapshot.id } })
                Divider()
            }
            if pieces.count < UFitOutfitInput.itemsMax {
                Button(Copy.product, action: onSelectProduct).frame(minHeight: Layout.touch)
                Button(Copy.inspiration) { pieces.append(UFitOutfitPieceDraft()) }.frame(minHeight: Layout.touch)
            }
            if let error { Text(error).font(.caption) }
        }
    }
    private func binding(for snapshot: UFitOutfitPieceDraft) -> Binding<UFitOutfitPieceDraft> {
        Binding(get: {
            // SwiftUI reads controls while removing their row. Keep that row's
            // rendered value for teardown, without retaining an array index.
            pieces.first(where: { $0.id == snapshot.id }) ?? snapshot
        }, set: { value in
            guard value.id == snapshot.id, let index = pieces.firstIndex(where: { $0.id == snapshot.id }) else { return }
            pieces[index] = value
        })
    }
    private struct PieceRow: View {
        @Binding var piece: UFitOutfitPieceDraft
        let canMoveBefore: Bool
        let canMoveAfter: Bool
        let onBefore: () -> Void
        let onAfter: () -> Void
        let onRemove: () -> Void
        var body: some View {
            VStack(alignment: .leading, spacing: Layout.gap) {
                if let product = piece.product {
                    HStack(spacing: Layout.gap) {
                        Group {
                            if let source = product.image { FashionImage(source: source) }
                            else { Rectangle().fill(Color.ufitBackground).overlay { Image(systemName: Icon.photo) } }
                        }.frame(width: Layout.thumbnail, height: Layout.thumbnail).clipShape(RoundedRectangle(cornerRadius: Layout.radius))
                        VStack(alignment: .leading, spacing: Layout.small) {
                            Text(product.name).font(.headline)
                            if let brand = product.brandName { Text(brand).font(.caption).foregroundStyle(Color.ufitMuted) }
                            Text(product.price ?? Copy.unavailable).font(.subheadline)
                        }
                    }
                } else {
                    UFitTextField(label: Copy.label, text: $piece.externalLabel)
                    Text(Copy.notForSale).font(.caption).foregroundStyle(Color.ufitMuted)
                }
                Picker(Copy.type, selection: $piece.type) { ForEach(UFitOutfitItemType.allCases) { Text($0.label).tag($0) } }.frame(minHeight: Layout.touch)
                Toggle(Copy.required, isOn: $piece.isRequired).frame(minHeight: Layout.touch)
                DisclosureGroup(Copy.note) { UFitTextField(label: Copy.note, text: $piece.note).padding(.top, Layout.small) }.frame(minHeight: Layout.touch)
                if piece.isProduct {
                    Button(Copy.replace) { piece.externalLabel = piece.title; piece.product = nil }.font(.callout).frame(minHeight: Layout.touch)
                }
                HStack {
                    Button(action: onBefore) { Image(systemName: Icon.up).frame(minWidth: Layout.touch, minHeight: Layout.touch) }.accessibilityLabel(Copy.up).disabled(!canMoveBefore)
                    Button(action: onAfter) { Image(systemName: Icon.down).frame(minWidth: Layout.touch, minHeight: Layout.touch) }.accessibilityLabel(Copy.down).disabled(!canMoveAfter)
                    Spacer()
                    Button(Copy.remove, action: onRemove).frame(minHeight: Layout.touch)
                }
            }
        }
    }
    private func move(_ id: UUID, step: Int) {
        guard let index = pieces.firstIndex(where: { $0.id == id }), pieces.indices.contains(index + step) else { return }
        pieces.swapAt(index, index + step)
    }
}
