import SwiftUI

struct UFitShipmentFormContent: View {
    let action: UFitShipmentAction
    @Binding var draft: UFitShipmentFormDraft
    let hasChanges: Bool
    let isSaving: Bool
    let isStale: Bool
    let errors: [UFitShipmentFormField: String]
    let message: String?
    let canRefresh: Bool
    let onClose: () -> Void
    let onSave: () -> Void
    let onRefresh: () -> Void
    @State private var leaving: Leaving?
    private enum Leaving: Equatable { case close, refresh }
    private enum Copy {
        static let carrier = String(localized: "Transporteur"); static let tracking = String(localized: "Numéro de suivi")
        static let url = String(localized: "Lien de suivi (facultatif)"); static let incident = String(localized: "Motif de l’incident")
        static let close = String(localized: "Annuler"); static let saving = String(localized: "Enregistrement en cours")
        static let refresh = String(localized: "Actualiser la commande"); static let discardTitle = String(localized: "Abandonner la saisie ?")
        static let refreshTitle = String(localized: "Actualiser et abandonner la saisie ?")
        static let discard = String(localized: "Abandonner"); static let refreshDiscard = String(localized: "Actualiser et abandonner")
        static let keep = String(localized: "Continuer la saisie")
    }
    private enum Layout {
        static let page: CGFloat = UFitSpace.xl; static let gap: CGFloat = UFitSpace.md; static let small: CGFloat = UFitSpace.xs; static let touch: CGFloat = UFitControlSize.touch; static let radius: CGFloat = UFitRadius.field
        static let minimumLines = 4; static let maximumLines = 10; static let disabledOpacity = 0.4; static let enabledOpacity = 1.0
    }
    private var saveDisabled: Bool { isSaving || isStale || (action == .updateTracking && !hasChanges) }
    var body: some View {
        VStack(spacing: .zero) {
            UFitSheetHeader(title: action.label, onClose: { requestLeaving(.close) }).disabled(isSaving)
            ScrollView {
                VStack(alignment: .leading, spacing: Layout.page) {
                    if action == .reportIncident {
                        UFitMultilineField(label: Copy.incident, text: $draft.incidentReason, error: errors[.incidentReason])
                    } else {
                        UFitTextField(label: Copy.carrier, text: $draft.carrier, error: errors[.carrier])
                        UFitTextField(label: Copy.tracking, text: $draft.trackingNumber, error: errors[.trackingNumber], isIdentifier: true)
                        UFitTextField(label: Copy.url, text: $draft.trackingURL, error: errors[.trackingURL], keyboard: .URL, isIdentifier: true)
                    }
                }.padding(Layout.page).frame(maxWidth: .infinity, alignment: .leading).disabled(isSaving)
            }.scrollDismissesKeyboard(.interactively)
                .safeAreaInset(edge: .bottom, spacing: .zero) {
                    VStack(alignment: .leading, spacing: Layout.small) {
                        if let message { Text(message).font(UFitTypography.callout) }
                        if canRefresh { UFitActionButton(title: Copy.refresh, kind: .secondary) { requestLeaving(.refresh) }.disabled(isSaving) }
                        if isSaving { UFitLoading(Copy.saving).frame(maxWidth: .infinity, minHeight: Layout.touch) }
                        else {
                            UFitButton(action: onSave) { Text(action.saveLabel).frame(maxWidth: .infinity) }.ufitButtonStyle(.primary)
                                .disabled(saveDisabled).opacity(saveDisabled ? Layout.disabledOpacity : Layout.enabledOpacity)
                        }
                    }.padding(Layout.gap).background(Color.ufitCanvas).overlay(alignment: .top) { Divider() }
                }
        }.foregroundStyle(Color.ufitInk).tint(Color.ufitInk).background(Color.ufitCanvas)
            .interactiveDismissDisabled(hasChanges || isSaving)
            .ufitConfirmationDialog(leaving == .refresh ? Copy.refreshTitle : Copy.discardTitle, isPresented: Binding(get: { leaving != nil }, set: { if !$0 { leaving = nil } }), titleVisibility: .visible, presenting: leaving) { action in
                UFitButton(action == .refresh ? Copy.refreshDiscard : Copy.discard, role: .destructive) {
                    if action == .refresh { onRefresh() } else { onClose() }; leaving = nil
                }
                UFitButton(Copy.keep, role: .cancel) { leaving = nil }
            }
    }
    private func requestLeaving(_ action: Leaving) {
        if hasChanges { leaving = action }
        else if action == .refresh { onRefresh() }
        else { onClose() }
    }
}
