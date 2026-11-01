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
    let onSubmit: (UFitCatalogRevision) -> Void
    let onApprove: (UFitCatalogRevision) -> Void
    let onReject: (UFitCatalogRevision, String) -> Void
    let onArchive: (UFitCatalogRevision) -> Void
    let onRestore: (UFitCatalogRevision) -> Void
    private enum LeaveAction { case back, refresh }
    @State private var pendingLeave: LeaveAction?
    @State private var confirmingLeave = false
    @State private var selectedImageID: String?
    @State private var archiveRevision: UFitCatalogRevision?
    @State private var refusalRevision: UFitCatalogRevision?
    @State private var confirmingArchive = false
    @State private var showingRefusal = false
    @State private var rejectionReason = String()
    @State private var invalidReason = false
    private enum Copy {
        static let discardReason = String(localized: "Abandonner le motif non envoyé ?")
        static let discard = String(localized: "Abandonner")
        static let keepEditing = String(localized: "Continuer la saisie")
        static let refresh = String(localized: "Actualiser la fiche")
        static let brand = String(localized: "Marque")
        static let title = String(localized: "Produit"); static let edit = String(localized: "Modifier"); static let retry = String(localized: "Réessayer")
        static let stock = String(localized: "Variantes et stock"); static let changeStock = String(localized: "Modifier le stock")
        static let stockLabel = String(localized: "Stock"); static let description = String(localized: "Description")
        static let material = String(localized: "Matière"); static let care = String(localized: "Entretien")
        static let feedback = String(localized: "Retour de l’équipe"); static let noImage = String(localized: "Photo manquante")
        static let decisions = String(localized: "Retour aux décisions")
        static let submit = String(localized: "Envoyer à validation"); static let approve = String(localized: "Valider le produit")
        static let refuse = String(localized: "Refuser"); static let reason = String(localized: "Motif du refus")
        static let reasonInvalid = String(localized: "Saisissez un motif de 1 à 2 000 caractères."); static let confirmRefusal = String(localized: "Confirmer le refus")
        static let archive = String(localized: "Archiver le produit"); static let archiveTitle = String(localized: "Archiver ce produit ?")
        static let archiveConsequence = String(localized: "Il ne sera plus proposé à l’achat.")
        static let restore = String(localized: "Remettre en brouillon"); static let cancel = String(localized: "Annuler")
        static let emptyVariants = String(localized: "Aucune variante."); static let loading = String(localized: "Chargement de la fiche")
    }
    private enum Layout { static let page: CGFloat = UFitSpace.xl; static let gap: CGFloat = UFitSpace.md; static let small: CGFloat = UFitSpace.xs; static let title: CGFloat = UFitTypography.Size.title; static let image: CGFloat = 240; static let touch: CGFloat = UFitControlSize.touch; static let editor: CGFloat = 130; static let bottom: CGFloat = 110; static let radius: CGFloat = UFitRadius.field; static let thumbnail: CGFloat = 64; static let border: CGFloat = UFitSpace.hairline }
    private enum Icon { static let photo = "photo"; static let refresh = "arrow.clockwise" }
    var body: some View {
        VStack(spacing: .zero) {
            DetailHeader(title: Copy.title, onBack: { requestLeave(.back) }) {
                HStack {
                    if isLoading || isMutatingProduct { UFitLoading().frame(minWidth: Layout.touch, minHeight: Layout.touch) }
                    else { UFitButton(action: { requestLeave(.refresh) }) { UFitIcon(systemName: Icon.refresh).frame(width: Layout.touch, height: Layout.touch) }.accessibilityLabel(Copy.refresh) }
                    if access == .member, product?.status.canEdit == true { UFitButton(Copy.edit, action: onEdit).frame(minHeight: Layout.touch) }
                }
            }.disabled(isMutatingProduct)
                .ufitConfirmationDialog(Copy.discardReason, isPresented: $confirmingLeave, titleVisibility: .visible) {
                    UFitButton(Copy.discard, role: .destructive) { if let action = pendingLeave { resetRefusal(); performLeave(action) } }
                    UFitButton(Copy.keepEditing, role: .cancel) { pendingLeave = nil }
                }
            if let message { Text(message).font(UFitTypography.callout).padding(Layout.gap).frame(maxWidth: .infinity, alignment: .leading) }
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
                        if let reason = product.rejectionReason {
                            VStack(alignment: .leading, spacing: Layout.small) { Text(Copy.feedback).font(UFitTypography.headline); Text(reason).font(UFitTypography.callout) }
                        }
                        variants(product)
                        VStack(alignment: .leading, spacing: Layout.small) { Text(Copy.description).font(UFitTypography.headline); Text(product.description).font(UFitTypography.callout) }
                        if let material = product.material { UFitLabeledValue(Copy.material, value: material).font(UFitTypography.callout) }
                        if let care = product.careInstructions { VStack(alignment: .leading, spacing: Layout.small) { Text(Copy.care).font(UFitTypography.headline); Text(care).font(UFitTypography.callout) } }
                        actions(product)
                    }.padding(Layout.page).padding(.bottom, UFitSpace.xl).frame(maxWidth: .infinity, alignment: .leading)
                } else if isLoading { UFitLoading(Copy.loading).padding(Layout.page) }
                else { UFitButton(Copy.retry, action: onRefresh).frame(minHeight: Layout.touch) }
            }
        }.foregroundStyle(Color.ufitInk).tint(Color.ufitInk).background(Color.ufitCanvas)
            .ufitConfirmationDialog(Copy.archiveTitle, isPresented: $confirmingArchive, titleVisibility: .visible) {
                UFitButton(Copy.archive, role: .destructive) { if let revision = archiveRevision { onArchive(revision) } }
                UFitButton(Copy.cancel, role: .cancel) {}
            } message: { Text(Copy.archiveConsequence) }
            .onChange(of: product?.id) { _, _ in selectedImageID = nil; confirmingArchive = false; archiveRevision = nil; resetRefusal() }
            .onChange(of: product?.version) { _, _ in confirmingArchive = false; archiveRevision = nil; resetRefusal() }
            .onChange(of: product?.images.map(\.id)) { _, ids in if let selectedImageID, ids?.contains(selectedImageID) != true { self.selectedImageID = nil } }
    }
    private func resetRefusal() { showingRefusal = false; rejectionReason = String(); refusalRevision = nil; invalidReason = false; pendingLeave = nil; confirmingLeave = false }
    private func requestLeave(_ action: LeaveAction) {
        if rejectionReason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { performLeave(action) }
        else { pendingLeave = action; confirmingLeave = true }
    }
    private func performLeave(_ action: LeaveAction) { switch action { case .back: onBack(); case .refresh: onRefresh() } }
    private func validReason(_ value: String) -> Bool { (Input.reasonMin...Input.reasonMax).contains(value.trimmingCharacters(in: .whitespacesAndNewlines).unicodeScalars.count) }
    private enum Input { static let reasonMin = 1; static let reasonMax = 2000 }
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
                        UFitButton(Copy.changeStock) { onStock(variant.id) }.frame(minHeight: Layout.touch).disabled(isMutatingProduct)
                    }
                }.padding(.vertical, Layout.small)
                Divider()
            }
        }
    }
    private func actions(_ product: UFitCatalogProductPresentation) -> some View {
        VStack(alignment: .leading, spacing: Layout.gap) {
            if access == .member && product.status.canSubmit {
                if let issue = product.submissionIssue { Text(issue).font(UFitTypography.callout).foregroundStyle(Color.ufitSecondaryText) }
                UFitButton(action: { onSubmit(product.revision) }) { Text(Copy.submit).frame(maxWidth: .infinity) }.ufitButtonStyle(.primary).disabled(isMutatingProduct || product.submissionIssue != nil)
            }
            if access == .moderator && product.status == .underReview {
                if !showingRefusal {
                    UFitButton(action: { onApprove(product.revision) }) { Text(Copy.approve).frame(maxWidth: .infinity) }.ufitButtonStyle(.primary).disabled(isMutatingProduct)
                    UFitButton(Copy.refuse) { refusalRevision = product.revision; showingRefusal = true }.frame(minHeight: Layout.touch).disabled(isMutatingProduct)
                }
                if showingRefusal {
                    UFitMultilineField(label: Copy.reason, text: $rejectionReason, error: invalidReason ? Copy.reasonInvalid : nil)
                        .onChange(of: rejectionReason) { _, value in if invalidReason { invalidReason = !validReason(value) } }
                    UFitButton(Copy.confirmRefusal) {
                        let reason = rejectionReason.trimmingCharacters(in: .whitespacesAndNewlines)
                        invalidReason = !validReason(reason)
                        if !invalidReason, let revision = refusalRevision { onReject(revision, reason) }
                    }.ufitButtonStyle(.primary).disabled(isMutatingProduct)
                    UFitButton(Copy.decisions) { showingRefusal = false }.frame(minHeight: Layout.touch).disabled(isMutatingProduct)
                }
            }
            if product.status == .archived {
                UFitButton(action: { onRestore(product.revision) }) { Text(Copy.restore).frame(maxWidth: .infinity) }.ufitButtonStyle(.primary).disabled(isMutatingProduct)
            } else if access == .member || product.status == .active {
                UFitButton(Copy.archive) { archiveRevision = product.revision; confirmingArchive = true }.frame(minHeight: Layout.touch).disabled(isMutatingProduct)
            }
        }
    }
}
