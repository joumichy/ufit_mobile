import SwiftUI

struct UFitCatalogProductContent: View {
    let product: UFitCatalogProductPresentation?
    let access: UFitCatalogAccess
    let isLoading: Bool
    let isMutatingProduct: Bool
    let message: String?
    let onBack: () -> Void
    let onRefresh: () -> Void
    let onEdit: () -> Void
    let onStock: (String) -> Void
    let onPublish: (UFitCatalogRevision) -> Void
    let onWithdraw: (UFitCatalogRevision) -> Void
    let onArchive: (UFitCatalogRevision) -> Void
    let onRestore: (UFitCatalogRevision) -> Void
    @State private var selectedImageID: String?
    @State private var archiveRevision: UFitCatalogRevision?
    @State private var confirmingArchive = false
    private enum Copy {
        static let refresh = String(localized: "Actualiser la fiche")
        static let brand = String(localized: "Marque")
        static let title = String(localized: "Produit"); static let edit = String(localized: "Modifier"); static let retry = String(localized: "Réessayer")
        static let stock = String(localized: "Variantes et stock"); static let changeStock = String(localized: "Modifier le stock")
        static let stockLabel = String(localized: "Stock"); static let description = String(localized: "Description")
        static let material = String(localized: "Matière"); static let care = String(localized: "Entretien")
        static let publish = String(localized: "Publier le produit"), withdraw = String(localized: "Retirer du catalogue")
        static let noImage = String(localized: "Photo manquante")
        static let archive = String(localized: "Archiver le produit"); static let archiveTitle = String(localized: "Archiver ce produit ?")
        static let archiveConsequence = String(localized: "Il ne sera plus proposé à l’achat.")
        static let restore = String(localized: "Remettre en brouillon"); static let cancel = String(localized: "Annuler")
        static let emptyVariants = String(localized: "Aucune variante."); static let loading = String(localized: "Chargement de la fiche")
    }
    private enum Layout { static let page: CGFloat = UFitSpace.xl; static let gap: CGFloat = UFitSpace.md; static let small: CGFloat = UFitSpace.xs; static let title: CGFloat = UFitTypography.Size.title; static let image: CGFloat = 240; static let touch: CGFloat = UFitControlSize.touch; static let editor: CGFloat = 130; static let bottom: CGFloat = 110; static let radius: CGFloat = UFitRadius.field; static let thumbnail: CGFloat = 64; static let border: CGFloat = UFitSpace.hairline }
    private enum Icon { static let photo = "photo" }
    var body: some View {
        VStack(spacing: .zero) {
            DetailHeader(title: Copy.title, onBack: onBack) {
                HStack {
                    if isLoading || isMutatingProduct { UFitLoading().frame(minWidth: Layout.touch, minHeight: Layout.touch) }
                }
            }.disabled(isMutatingProduct)
            if let message {
                VStack(alignment: .leading, spacing: Layout.small) {
                    Text(message).font(UFitTypography.callout)
                    if product != nil { UFitActionButton(title: Copy.refresh, kind: .secondary, disabled: isLoading || isMutatingProduct, action: onRefresh) }
                }.padding(Layout.gap).frame(maxWidth: .infinity, alignment: .leading)
            }
            ScrollView {
                if let product {
                    VStack(alignment: .leading, spacing: Layout.page) {
                        photos(product)
                        VStack(alignment: .leading, spacing: Layout.small) {
                            UFitLabeledValue(Copy.brand) {
                                VStack(alignment: .trailing, spacing: Layout.small) {
                                    Text(product.brandName)
                                    Text(product.brandStatus.label).foregroundStyle(Color.ufitSecondaryText)
                                }
                            }.font(UFitTypography.callout)
                            Text(product.status.label).font(UFitTypography.caption.weight(.semibold)).foregroundStyle(Color.ufitSecondaryText)
                            Text(product.name).ufitFont(size: Layout.title, design: .serif)
                            Text(product.price).font(UFitTypography.title3.weight(.medium))
                            Text(product.category).font(UFitTypography.callout).foregroundStyle(Color.ufitSecondaryText)
                        }
                        variants(product)
                        VStack(alignment: .leading, spacing: Layout.small) { Text(Copy.description).font(UFitTypography.headline); Text(product.description).font(UFitTypography.callout) }
                        if let material = product.material { UFitLabeledValue(Copy.material, value: material).font(UFitTypography.callout) }
                        if let care = product.careInstructions { VStack(alignment: .leading, spacing: Layout.small) { Text(Copy.care).font(UFitTypography.headline); Text(care).font(UFitTypography.callout) } }
                        actions(product)
                    }.padding(Layout.page).padding(.bottom, UFitSpace.xl).frame(maxWidth: .infinity, alignment: .leading)
                } else if isLoading { UFitLoading(Copy.loading).padding(Layout.page) }
                else { UFitActionButton(title: Copy.retry, kind: .secondary, action: onRefresh).padding(Layout.page) }
            }.ufitRefreshable(isEnabled: !isLoading && !isMutatingProduct, title: Copy.refresh) { onRefresh() }
        }.foregroundStyle(Color.ufitInk).tint(Color.ufitInk).background(Color.ufitCanvas)
            .ufitConfirmationDialog(Copy.archiveTitle, isPresented: $confirmingArchive, titleVisibility: .visible) {
                UFitButton(Copy.archive, role: .destructive) { if let revision = archiveRevision { onArchive(revision) } }
                UFitButton(Copy.cancel, role: .cancel) {}
            } message: { Text(Copy.archiveConsequence) }
            .onChange(of: product?.id) { _, _ in selectedImageID = nil; confirmingArchive = false; archiveRevision = nil }
            .onChange(of: product?.version) { _, _ in confirmingArchive = false; archiveRevision = nil }
            .onChange(of: product?.images.map(\.id)) { _, ids in if let selectedImageID, ids?.contains(selectedImageID) != true { self.selectedImageID = nil } }
    }
    @ViewBuilder private func photos(_ product: UFitCatalogProductPresentation) -> some View {
        if product.images.isEmpty {
            VStack(spacing: Layout.small) { UFitIcon(systemName: Icon.photo); Text(Copy.noImage) }.frame(maxWidth: .infinity, minHeight: Layout.image).foregroundStyle(Color.ufitSecondaryText)
        } else {
            VStack(spacing: Layout.small) {
                if let selected = product.images.first(where: { $0.id == selectedImageID }) {
                    FashionImage(source: selected.source).frame(height: Layout.image).clipped().clipShape(RoundedRectangle(cornerRadius: Layout.radius)).accessibilityLabel(selected.kindLabel)
                } else if let cover = product.images.first {
                    FashionImage(source: cover.source).frame(height: Layout.image).clipped().clipShape(RoundedRectangle(cornerRadius: Layout.radius)).accessibilityLabel(cover.kindLabel)
                }
                if product.images.count > Gallery.minimumForThumbnails {
                    ScrollView(.horizontal) {
                        HStack(spacing: Layout.small) {
                            ForEach(product.images) { image in
                                UFitButton { selectedImageID = image.id } label: {
                                    FashionImage(source: image.source).frame(width: Layout.thumbnail, height: Layout.thumbnail).clipped().clipShape(RoundedRectangle(cornerRadius: Layout.radius))
                                        .overlay { RoundedRectangle(cornerRadius: Layout.radius).stroke(selectedImageID == image.id ? Color.ufitInk : Color.ufitBorder, lineWidth: Layout.border) }
                                }.ufitButtonStyle(.text).accessibilityLabel(image.kindLabel)
                            }
                        }
                    }
                }
            }
        }
    }
    private enum Gallery { static let minimumForThumbnails = 1 }
    private func variants(_ product: UFitCatalogProductPresentation) -> some View {
        VStack(alignment: .leading, spacing: Layout.gap) {
            Text(Copy.stock).font(UFitTypography.title2.weight(.medium))
            if product.variants.isEmpty { Text(Copy.emptyVariants).font(UFitTypography.callout).foregroundStyle(Color.ufitSecondaryText) }
            ForEach(product.variants) { variant in
                VStack(alignment: .leading, spacing: Layout.small) {
                    HStack { Text(variant.title).font(UFitTypography.headline); Spacer(); Text(variant.status.label).font(UFitTypography.caption).foregroundStyle(Color.ufitSecondaryText) }
                    Text(variant.sku).font(UFitTypography.caption).foregroundStyle(Color.ufitSecondaryText)
                    HStack { Text(variant.price); Spacer(); HStack(spacing: Layout.small) { Text(Copy.stockLabel).foregroundStyle(Color.ufitSecondaryText); Text(variant.stockQuantity, format: .number) } }.font(UFitTypography.callout)
                    if access == .member && product.status != .archived && variant.status != .archived {
                        UFitActionButton(title: Copy.changeStock, kind: .secondary, disabled: isMutatingProduct) { onStock(variant.id) }
                    }
                }.padding(.vertical, Layout.small)
                Divider()
            }
        }
    }
    private func actions(_ product: UFitCatalogProductPresentation) -> some View {
        VStack(spacing: Layout.gap) {
            if access == .member {
                if product.status.canPublish {
                    if let issue = product.publicationIssue { UFitNotice(message: issue, kind: .information) }
                    UFitActionButton(title: Copy.publish, isBusy: isMutatingProduct, disabled: isLoading || product.publicationIssue != nil) { onPublish(product.revision) }
                }
                if product.status.canEdit { UFitActionButton(title: Copy.edit, kind: .secondary, disabled: isMutatingProduct, action: onEdit) }
                if product.status == .active {
                    UFitActionButton(title: Copy.withdraw, kind: .secondary, role: .destructive, disabled: isMutatingProduct) { onWithdraw(product.revision) }
                }
            }
            if product.status == .archived {
                UFitActionButton(title: Copy.restore, isBusy: isMutatingProduct) { onRestore(product.revision) }
            } else {
                UFitActionButton(title: Copy.archive, kind: .secondary, role: .destructive, disabled: isMutatingProduct) {
                    archiveRevision = product.revision; confirmingArchive = true
                }.padding(.top, UFitSpace.xs)
            }
        }
    }
}
