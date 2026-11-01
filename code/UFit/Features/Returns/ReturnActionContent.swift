import SwiftUI

struct UFitReturnActionContent: View {
    let action: UFitReturnAction
    let items: [UFitOrderPiece]
    let amount: String
    @Binding var draft: UFitReturnActionDraft
    let hasChanges: Bool
    let isSaving: Bool
    let isStale: Bool
    let errors: [UFitReturnActionField: String]
    let message: String?
    let canRefresh: Bool
    let onClose: () -> Void
    let onSave: () -> Void
    let onRefresh: () -> Void
    @State private var leaving: Leaving?
    private enum Leaving: Equatable { case close, refresh }
    private enum Copy {
        static let reason = String(localized: "Motif de la décision"); static let disputeReason = String(localized: "Pourquoi demandez-vous un arbitrage ?")
        static let instructions = String(localized: "Adresse et instructions de retour"); static let carrier = String(localized: "Transporteur du retour")
        static let tracking = String(localized: "Numéro de suivi du retour"); static let url = String(localized: "Lien de suivi (facultatif)")
        static let close = String(localized: "Annuler"); static let saving = String(localized: "Enregistrement en cours")
        static let refresh = String(localized: "Actualiser le dossier"); static let discardTitle = String(localized: "Abandonner la saisie ?")
        static let refreshTitle = String(localized: "Actualiser et abandonner la saisie ?")
        static let discard = String(localized: "Abandonner"); static let refreshDiscard = String(localized: "Actualiser et abandonner"); static let keep = String(localized: "Continuer la saisie")
        static let restock = String(localized: "Remise en stock"); static let choose = String(localized: "Choisir")
        static let noRestock = String(localized: "Ne rien remettre en stock")
        static let receiptNote = String(localized: "Confirmez seulement après réception des pièces. Choisissez explicitement la quantité revendable pour chaque ligne. Le remboursement sera déclenché sur le moyen de paiement d’origine et restera en cours jusqu’à confirmation du prestataire.")
    }
    private enum Layout {
        static let page: CGFloat = 24; static let gap: CGFloat = 16; static let small: CGFloat = 8; static let touch: CGFloat = 44
        static let disabledOpacity = 0.4; static let enabledOpacity = 1.0; static let quantityStep = 1
    }
    private var saveDisabled: Bool { isSaving || isStale || (action == .updateTracking && !hasChanges) }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Layout.page) {
                    if action.needsReason { UFitMultilineField(label: action == .dispute ? Copy.disputeReason : Copy.reason, text: $draft.reason, error: errors[.reason]) }
                    if action.needsInstructions { UFitMultilineField(label: Copy.instructions, text: $draft.instructions, error: errors[.instructions]) }
                    if action.needsTracking {
                        UFitTextField(label: Copy.carrier, text: $draft.carrier, error: errors[.carrier])
                        UFitTextField(label: Copy.tracking, text: $draft.trackingNumber, error: errors[.trackingNumber], isIdentifier: true)
                        UFitTextField(label: Copy.url, text: $draft.trackingURL, error: errors[.trackingURL], keyboard: .URL, isIdentifier: true)
                    }
                    if action == .receive {
                        Text(Copy.receiptNote).font(.callout)
                        Text(String(localized: "Remboursement : \(amount)")).font(.headline)
                        ForEach(items) { item in
                            UFitOrderPieceContent(item: item)
                            VStack(alignment: .leading, spacing: Layout.small) {
                                HStack {
                                    Text(Copy.restock).font(.subheadline.weight(.medium)); Spacer()
                                    if let quantity = draft.restockQuantities[item.id] {
                                        Text(String(localized: "\(quantity) sur \(item.quantity)"))
                                    } else { Text(Copy.choose).foregroundStyle(Color.ufitMuted) }
                                }
                                if draft.restockQuantities[item.id] == nil {
                                    Button(Copy.noRestock) { draft.restockQuantities[item.id] = .zero }.frame(minHeight: Layout.touch)
                                }
                                Stepper(value: stock(item), in: .zero...item.quantity, step: Layout.quantityStep) {
                                    Text(String(localized: "Quantité revendable de \(item.name)"))
                                }.frame(minHeight: Layout.touch)
                                if let error = errors[.restock(item.id)] { Text(error).font(.caption) }
                            }
                            Divider()
                        }
                    }
                }.padding(Layout.page).frame(maxWidth: .infinity, alignment: .leading).disabled(isSaving)
            }.scrollDismissesKeyboard(.interactively)
                .safeAreaInset(edge: .bottom, spacing: .zero) {
                    VStack(alignment: .leading, spacing: Layout.small) {
                        if let message { Text(message).font(.callout) }
                        if canRefresh { Button(Copy.refresh) { requestLeaving(.refresh) }.frame(minHeight: Layout.touch).disabled(isSaving) }
                        if isSaving { ProgressView(Copy.saving).frame(maxWidth: .infinity, minHeight: Layout.touch) }
                        else { Button(action: onSave) { Text(action.saveLabel).multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true).padding(.horizontal, Layout.gap).frame(maxWidth: .infinity) }.buttonStyle(PrimaryButtonStyle()).disabled(saveDisabled).opacity(saveDisabled ? Layout.disabledOpacity : Layout.enabledOpacity) }
                    }.padding(Layout.gap).background(Color.white).overlay(alignment: .top) { Divider() }
                }.navigationTitle(action.label).navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button(Copy.close) { requestLeaving(.close) }.disabled(isSaving) } }
        }.foregroundStyle(Color.ufitInk).tint(Color.ufitInk).background(Color.white).interactiveDismissDisabled(hasChanges || isSaving)
            .confirmationDialog(leaving == .refresh ? Copy.refreshTitle : Copy.discardTitle, isPresented: Binding(get: { leaving != nil }, set: { if !$0 { leaving = nil } }), titleVisibility: .visible, presenting: leaving) { value in
                Button(value == .refresh ? Copy.refreshDiscard : Copy.discard, role: .destructive) { if value == .refresh { onRefresh() } else { onClose() }; leaving = nil }
                Button(Copy.keep, role: .cancel) { leaving = nil }
            }
    }
    private func stock(_ item: UFitOrderPiece) -> Binding<Int> { Binding(get: { draft.restockQuantities[item.id] ?? .zero }, set: { draft.restockQuantities[item.id] = $0 }) }
    private func requestLeaving(_ action: Leaving) {
        if hasChanges { leaving = action } else if action == .refresh { onRefresh() } else { onClose() }
    }
}
