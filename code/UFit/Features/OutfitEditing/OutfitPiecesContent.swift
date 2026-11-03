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
        static let unnamed = String(localized: "Pièce d’inspiration à nommer")
        static let optional = String(localized: "Pièce facultative")
        static func settings(_ name: String) -> String { String(localized: "Réglages · \(name)") }
        static let unavailable = String(localized: "Produit indisponible")
        static let up = String(localized: "Déplacer la pièce avant"); static let down = String(localized: "Déplacer la pièce après"); static let remove = String(localized: "Retirer la pièce")
    }
    private enum Layout { static let gap: CGFloat = UFitSpace.md; static let small: CGFloat = UFitSpace.xs; static let touch: CGFloat = UFitControlSize.touch; static let thumbnail: CGFloat = 68; static let radius: CGFloat = UFitRadius.field }
    private enum Icon { static let up = "arrow.up"; static let down = "arrow.down" }
    var body: some View {
        VStack(alignment: .leading, spacing: Layout.gap) {
            Text(Copy.title).font(UFitTypography.title2.weight(.medium)).accessibilityAddTraits(.isHeader)
            if pieces.isEmpty { Text(Copy.empty).font(UFitTypography.callout).foregroundStyle(Color.ufitSecondaryText) }
            ForEach(pieces) { snapshot in
                PieceRow(piece: binding(for: snapshot), canMoveBefore: pieces.first?.id != snapshot.id,
                    canMoveAfter: pieces.last?.id != snapshot.id,
                    onBefore: { move(snapshot.id, step: -UFitOutfitInput.positionStep) },
                    onAfter: { move(snapshot.id, step: UFitOutfitInput.positionStep) },
                    onRemove: { pieces.removeAll { $0.id == snapshot.id } })
                Divider()
            }
            if pieces.count < UFitOutfitInput.itemsMax {
                UFitActionButton(title: Copy.product, kind: .secondary, action: onSelectProduct)
                UFitActionButton(title: Copy.inspiration, kind: .secondary) { pieces.append(UFitOutfitPieceDraft()) }
            }
            if let error { UFitFieldError(message: error) }
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
        private var title: String {
            let value = UFitOutfitInput.trimmed(piece.title)
            return value.isEmpty ? Copy.unnamed : value
        }
        var body: some View {
            VStack(alignment: .leading, spacing: Layout.gap) {
                HStack(alignment: .top, spacing: Layout.gap) {
                    Group {
                        if let source = piece.product?.image { FashionImage(source: source) }
                        else { Rectangle().fill(Color.ufitBackground).overlay { UFitOutfitItemIcon(symbol: piece.type.symbol) } }
                    }.frame(width: Layout.thumbnail, height: Layout.thumbnail).clipShape(RoundedRectangle(cornerRadius: Layout.radius)).accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: Layout.small) {
                        Text(title).font(UFitTypography.headline)
                        if let product = piece.product {
                            if let brand = product.brandName { Text(brand).font(UFitTypography.caption).foregroundStyle(Color.ufitSecondaryText) }
                            Text(product.price ?? Copy.unavailable).font(UFitTypography.subheadline)
                        } else {
                            Text(Copy.notForSale).font(UFitTypography.caption).foregroundStyle(Color.ufitSecondaryText)
                        }
                        Text(piece.type.label).font(UFitTypography.caption).foregroundStyle(Color.ufitSecondaryText)
                        if !piece.isRequired { Text(Copy.optional).font(UFitTypography.caption).foregroundStyle(Color.ufitSecondaryText) }
                    }
                    Spacer(minLength: .zero)
                }
                UFitDisclosure(Copy.settings(title), initiallyExpanded: piece.serverID == nil || UFitOutfitInput.trimmed(piece.title).isEmpty) {
                    VStack(alignment: .leading, spacing: Layout.gap) {
                        if !piece.isProduct { UFitTextField(label: Copy.label, text: $piece.externalLabel) }
                        VStack(alignment: .leading, spacing: Layout.small) {
                            Text(Copy.type).font(UFitTypography.subheadline.weight(.medium))
                            UFitSelection(Copy.type, selection: $piece.type, options: UFitOutfitItemType.allCases.map { .init(value: $0, title: $0.label) }).frame(minHeight: Layout.touch)
                        }
                        UFitToggle(Copy.required, isOn: $piece.isRequired).frame(minHeight: Layout.touch)
                        UFitDisclosure(Copy.note) { UFitTextField(label: Copy.note, text: $piece.note).padding(.top, Layout.small) }.frame(minHeight: Layout.touch)
                        if piece.isProduct {
                            UFitActionButton(title: Copy.replace, kind: .secondary) { piece.externalLabel = piece.title; piece.product = nil }
                        }
                        HStack {
                            UFitButton(action: onBefore) { UFitIcon(systemName: Icon.up).frame(minWidth: Layout.touch, minHeight: Layout.touch) }.accessibilityLabel(Copy.up).disabled(!canMoveBefore)
                            UFitButton(action: onAfter) { UFitIcon(systemName: Icon.down).frame(minWidth: Layout.touch, minHeight: Layout.touch) }.accessibilityLabel(Copy.down).disabled(!canMoveAfter)
                            Spacer()
                            UFitButton(Copy.remove, role: .destructive, action: onRemove).ufitButtonStyle(.secondary, compact: true)
                        }
                    }.padding(.top, Layout.small)
                }
            }
        }
    }
    private func move(_ id: UUID, step: Int) {
        guard let index = pieces.firstIndex(where: { $0.id == id }), pieces.indices.contains(index + step) else { return }
        pieces.swapAt(index, index + step)
    }
}
