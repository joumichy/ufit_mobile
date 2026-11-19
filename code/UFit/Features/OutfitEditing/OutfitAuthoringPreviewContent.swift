import SwiftUI

struct UFitOutfitAuthoringPreviewContent: View {
    let draft: UFitOutfitDraft
    let onClose: () -> Void
    var renewPhotoSource: ((UUID) async throws -> String)? = nil
    @State private var selectedPhotoID: UUID?
    @State private var showingPieces = false
    @State private var selectedReference: OutfitProduct?
    private enum Copy {
        static let title = String(localized: "Aperçu client")
        static let empty = String(localized: "Ajoutez une photo pour prévisualiser la tenue.")
        static let emptyAction = String(localized: "Retour à la composition")
        static let pieces = String(localized: "Voir les pièces")
        static let hide = String(localized: "Masquer les pièces")
        static let emptyPieces = String(localized: "Aucune pièce associée")
        static let inspiration = String(localized: "Inspiration · non vendue sur Ufit")
        static let availability = String(localized: "La disponibilité sera vérifiée avant l’achat.")
        static let unnamed = String(localized: "Pièce d’inspiration à nommer")
        static let closeReference = String(localized: "Fermer la référence")
        static let reference = String(localized: "Référence")
        static let bag = "bag"
        static let photo = "photo"
    }
    private enum Layout {
        static let step = 1
        static let ribbonBottom: CGFloat = 116
        static let minimumRibbon: CGFloat = UFitControlSize.circularAction
        static let gradientOpacity = 0.55
        static let unavailableOpacity = 0.4
        static let availableOpacity = 1.0
        static let referenceHeightRatio = 0.75
    }
    private enum Icon { static let close = "xmark" }
    private var products: [OutfitProduct] {
        draft.pieces.map { piece in
            let name = UFitOutfitInput.trimmed(piece.title)
            return .init(id: piece.id.uuidString, itemType: piece.type, name: name.isEmpty ? Copy.unnamed : name,
                productID: piece.product?.id, brandID: nil, image: piece.product?.image,
                brandName: piece.product?.brandName, price: piece.product?.price)
        }
    }
    private var photoSelection: Binding<UUID?> {
        Binding(get: { draft.photos.first(where: { $0.id == selectedPhotoID })?.id ?? draft.photos.first?.id }, set: { selectedPhotoID = $0 })
    }
    var body: some View {
        VStack(spacing: .zero) {
            UFitSheetHeader(title: Copy.title, onClose: onClose).padding(.bottom, UFitSpace.md)
            if draft.photos.isEmpty {
                UFitEmptyState(title: Copy.empty, symbol: Copy.photo, actionTitle: Copy.emptyAction, action: onClose)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                GeometryReader { geometry in
                    ZStack(alignment: .bottomTrailing) {
                        UFitOutfitDraftPhotoPages(photos: draft.photos, selection: photoSelection, renewSource: renewPhotoSource)
                        LinearGradient(colors: [.clear, .black.opacity(Layout.gradientOpacity)], startPoint: .center, endPoint: .bottom).allowsHitTesting(false)
                        if showingPieces && selectedReference == nil {
                            UFitOutfitPiecesRibbon(items: products, onSelect: { selectedReference = $0 },
                                maximumHeight: max(Layout.minimumRibbon, geometry.size.height - Layout.ribbonBottom - UFitSpace.xl))
                                .padding(.trailing, UFitSpace.xl).padding(.bottom, Layout.ribbonBottom)
                        }
                        VStack(spacing: UFitSpace.md) {
                            HStack {
                                Spacer()
                                UFitButton { showingPieces.toggle() } label: {
                                    CircularIconButton(systemImage: Copy.bag, accessibilityLabel: products.isEmpty ? Copy.emptyPieces : (showingPieces ? Copy.hide : Copy.pieces))
                                }.ufitButtonStyle(.text).foregroundStyle(.white).disabled(products.isEmpty)
                                    .opacity(products.isEmpty ? Layout.unavailableOpacity : Layout.availableOpacity)
                            }.padding(.horizontal, UFitSpace.xl)
                            if draft.photos.count > Layout.step {
                                UFitPhotoPageControl(count: draft.photos.count, selection: Binding(get: {
                                    draft.photos.firstIndex(where: { $0.id == photoSelection.wrappedValue }) ?? .zero
                                }, set: { index in
                                    if draft.photos.indices.contains(index) { photoSelection.wrappedValue = draft.photos[index].id }
                                }), tint: .white)
                            }
                        }.padding(.bottom, UFitSpace.md)
                            .accessibilityHidden(selectedReference != nil).allowsHitTesting(selectedReference == nil)
                        if let item = selectedReference {
                            ViewThatFits(in: .vertical) {
                                reference(item).fixedSize(horizontal: false, vertical: true)
                                    .background(Color.ufitCanvas, in: RoundedRectangle(cornerRadius: UFitRadius.card))
                                ScrollView { reference(item) }.scrollBounceBehavior(.basedOnSize)
                                    .background(Color.ufitCanvas, in: RoundedRectangle(cornerRadius: UFitRadius.card))
                            }.frame(maxHeight: geometry.size.height * Layout.referenceHeightRatio, alignment: .bottom)
                                .padding(UFitSpace.md)
                        }
                    }.clipped()
                }
            }
        }.foregroundStyle(Color.ufitInk).background(Color.ufitCanvas)
    }
    private func reference(_ item: OutfitProduct) -> some View {
        VStack(alignment: .leading, spacing: UFitSpace.md) {
            HStack {
                Text(Copy.reference).font(UFitTypography.caption).foregroundStyle(Color.ufitSecondaryText)
                Spacer(minLength: UFitSpace.xs)
                UFitButton { selectedReference = nil } label: { UFitIcon(systemName: Icon.close) }
                    .ufitButtonStyle(.text).accessibilityLabel(Copy.closeReference)
            }
            UFitOutfitReferenceContent(item: item)
            Text(item.productID == nil ? Copy.inspiration : Copy.availability)
                .font(UFitTypography.callout).foregroundStyle(Color.ufitSecondaryText)
        }.padding(UFitSpace.md).accessibilityElement(children: .contain)
    }
}
