import SwiftUI

struct UFitReturnCreationContent: View {
    let options: UFitReturnOptionsPresentation?
    @Binding var draft: UFitReturnCreationDraft
    let preview: UFitReturnAmountsPresentation?
    let hasChanges: Bool
    let isLoading: Bool
    let isSaving: Bool
    let isUnresolved: Bool
    let errors: [UFitReturnCreationField: String]
    let message: String?
    let onClose: () -> Void
    let onRefresh: () -> Void
    let onPreview: () -> Void
    let onSubmit: () -> Void
    let onEdit: () -> Void
    let onOpenExisting: () -> Void
    @State private var confirmingClose = false
    private enum Copy {
        static let title = String(localized: "Demander un retour"); static let close = String(localized: "Annuler")
        static let loading = String(localized: "Chargement des pièces éligibles"); static let unavailable = String(localized: "Retour indisponible")
        static let refresh = String(localized: "Actualiser"); static let reason = String(localized: "Motif du retour")
        static let quantity = String(localized: "Quantité à retourner"); static let conditions = String(localized: "Conditions de retour à l’achat")
        static let preview = String(localized: "Vérifier le remboursement"); static let submit = String(localized: "Envoyer la demande")
        static let edit = String(localized: "Modifier la demande"); static let saving = String(localized: "Envoi en cours")
        static let existing = String(localized: "Ouvrir le retour en cours"); static let discardTitle = String(localized: "Abandonner la demande ?")
        static let discard = String(localized: "Abandonner"); static let keep = String(localized: "Continuer la demande")
        static let unresolved = String(localized: "L’envoi n’est pas encore confirmé. Réessayez pour retrouver cette même demande.")
        static let merchandise = String(localized: "Pièces retournées"); static let shipping = String(localized: "Livraison remboursée")
        static let taxes = String(localized: "Taxes remboursées"); static let total = String(localized: "Total remboursable")
        static let reviewNote = String(localized: "Vérifiez les pièces et le montant avant d’envoyer. La marque examinera votre demande ; le remboursement suivra la réception du retour accepté.")
    }
    private enum Layout {
        static let page: CGFloat = 24; static let gap: CGFloat = 16; static let small: CGFloat = 8; static let touch: CGFloat = 44
        static let imageWidth: CGFloat = 72; static let imageHeight: CGFloat = 94; static let singlePiece = 1
    }
    private enum Anchor { case amounts }
    private var locked: Bool { isLoading || isSaving || isUnresolved || preview != nil }
    var body: some View {
        NavigationStack {
            ScrollViewReader { reader in
            ScrollView {
                VStack(alignment: .leading, spacing: Layout.page) {
                    if let options {
                        Text(options.orderNumber).font(.title2.weight(.semibold))
                        if let date = options.deadline { Text(String(localized: "Demande possible jusqu’au \(date)")).font(.subheadline) }
                        if let policy = options.returnPolicy { VStack(alignment: .leading, spacing: Layout.small) { Text(Copy.conditions).font(.headline); Text(policy).font(.callout) } }
                        Text(options.refundPolicy.explanation).font(.footnote).foregroundStyle(Color.ufitMuted)
                        if options.canRequest || isUnresolved || preview != nil {
                            ForEach(options.items) { item in
                                VStack(alignment: .leading, spacing: Layout.gap) {
                                    HStack(alignment: .top, spacing: Layout.gap) {
                                        if let image = item.image { FashionImage(source: image).frame(width: Layout.imageWidth, height: Layout.imageHeight).clipped() }
                                        VStack(alignment: .leading, spacing: Layout.small) {
                                            Text(item.name).font(.headline); Text(item.options).font(.subheadline).foregroundStyle(Color.ufitMuted); Text(item.unitAmount).font(.subheadline)
                                            Text(item.availableQuantity == Layout.singlePiece ? String(localized: "1 pièce éligible") : String(localized: "\(item.availableQuantity) pièces éligibles")).font(.caption)
                                        }
                                    }
                                    Stepper(value: quantity(item), in: .zero...item.availableQuantity) {
                                        Text(String(localized: "\(Copy.quantity) : \(draft.quantities[item.id] ?? .zero)"))
                                    }.frame(minHeight: Layout.touch).disabled(locked)
                                    if let error = errors[.quantity(item.id)] { Text(error).font(.caption) }
                                }
                                Divider()
                            }
                            if let error = errors[.selection] { Text(error).font(.callout) }
                            UFitMultilineField(label: Copy.reason, text: $draft.reason, error: errors[.reason]).disabled(locked)
                        } else {
                            Text(options.unavailableNote ?? Copy.unavailable).font(.callout)
                            if options.openReturnID != nil { Button(Copy.existing, action: onOpenExisting).frame(minHeight: Layout.touch) }
                        }
                        if let preview {
                            VStack(spacing: Layout.gap) {
                                amount(Copy.merchandise, preview.merchandise); amount(Copy.shipping, preview.shipping); amount(Copy.taxes, preview.taxes)
                                Divider(); amount(Copy.total, preview.total).fontWeight(.semibold)
                            }.id(Anchor.amounts)
                            Text(Copy.reviewNote).font(.callout)
                        }
                    } else if isLoading { ProgressView(Copy.loading).frame(maxWidth: .infinity) }
                    else { Text(Copy.unavailable); Button(Copy.refresh, action: onRefresh).frame(minHeight: Layout.touch) }
                }.padding(Layout.page).frame(maxWidth: .infinity, alignment: .leading)
            }.scrollDismissesKeyboard(.interactively)
                .onChange(of: preview != nil) { _, ready in if ready { reader.scrollTo(Anchor.amounts, anchor: .top) } }
                .safeAreaInset(edge: .bottom, spacing: .zero) {
                    VStack(alignment: .leading, spacing: Layout.small) {
                        if let message {
                            Text(message).font(.callout)
                            if !isUnresolved { Button(Copy.refresh, action: onRefresh).frame(minHeight: Layout.touch).disabled(isLoading || isSaving) }
                        }
                        if isUnresolved { Text(Copy.unresolved).font(.callout) }
                        if isSaving || isLoading { ProgressView(isSaving ? Copy.saving : Copy.loading).frame(maxWidth: .infinity, minHeight: Layout.touch) }
                        else if options?.canRequest == true || isUnresolved {
                            if preview != nil && !isUnresolved { Button(Copy.edit, action: onEdit).frame(minHeight: Layout.touch) }
                            Button(action: preview == nil && !isUnresolved ? onPreview : onSubmit) { Text(preview == nil && !isUnresolved ? Copy.preview : Copy.submit).multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true).padding(.horizontal, Layout.gap).frame(maxWidth: .infinity) }.buttonStyle(PrimaryButtonStyle())
                        }
                    }.padding(Layout.gap).background(Color.white).overlay(alignment: .top) { Divider() }
                }.navigationTitle(Copy.title).navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button(Copy.close) { if hasChanges && !isUnresolved { confirmingClose = true } else { onClose() } }.disabled(isSaving) } }
            }
        }.foregroundStyle(Color.ufitInk).tint(Color.ufitInk).background(Color.white).interactiveDismissDisabled(hasChanges || isSaving)
            .confirmationDialog(Copy.discardTitle, isPresented: $confirmingClose, titleVisibility: .visible) {
                Button(Copy.discard, role: .destructive, action: onClose); Button(Copy.keep, role: .cancel) {}
            }
    }
    private func quantity(_ item: UFitReturnSelectablePiece) -> Binding<Int> { Binding(get: { draft.quantities[item.id] ?? .zero }, set: { draft.quantities[item.id] = $0 }) }
    private func amount(_ label: String, _ value: String) -> some View { HStack { Text(label); Spacer(); Text(value) } }
}
