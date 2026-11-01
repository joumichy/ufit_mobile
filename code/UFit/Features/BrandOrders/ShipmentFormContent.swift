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
        static let page: CGFloat = 24; static let gap: CGFloat = 16; static let small: CGFloat = 8; static let touch: CGFloat = 44; static let radius: CGFloat = 12
        static let minimumLines = 4; static let maximumLines = 10; static let disabledOpacity = 0.4; static let enabledOpacity = 1.0
    }
    private var saveDisabled: Bool { isSaving || isStale || (action == .updateTracking && !hasChanges) }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Layout.page) {
                    if action == .reportIncident {
                        VStack(alignment: .leading, spacing: Layout.small) {
                            Text(Copy.incident).font(.subheadline.weight(.medium))
                            TextField(Copy.incident, text: $draft.incidentReason, axis: .vertical).lineLimit(Layout.minimumLines...Layout.maximumLines).padding(Layout.gap)
                                .overlay { RoundedRectangle(cornerRadius: Layout.radius).stroke(Color.ufitBorder) }.accessibilityLabel(Copy.incident)
                            if let error = errors[.incidentReason] { Text(error).font(.caption) }
                        }
                    } else {
                        UFitTextField(label: Copy.carrier, text: $draft.carrier, error: errors[.carrier])
                        UFitTextField(label: Copy.tracking, text: $draft.trackingNumber, error: errors[.trackingNumber], isIdentifier: true)
                        UFitTextField(label: Copy.url, text: $draft.trackingURL, error: errors[.trackingURL], keyboard: .URL, isIdentifier: true)
                    }
                }.padding(Layout.page).frame(maxWidth: .infinity, alignment: .leading).disabled(isSaving)
            }.scrollDismissesKeyboard(.interactively)
                .safeAreaInset(edge: .bottom, spacing: .zero) {
                    VStack(alignment: .leading, spacing: Layout.small) {
                        if let message { Text(message).font(.callout) }
                        if canRefresh { Button(Copy.refresh) { requestLeaving(.refresh) }.frame(minHeight: Layout.touch).disabled(isSaving) }
                        if isSaving { ProgressView(Copy.saving).frame(maxWidth: .infinity, minHeight: Layout.touch) }
                        else {
                            Button(action: onSave) { Text(action.saveLabel).frame(maxWidth: .infinity) }.buttonStyle(PrimaryButtonStyle())
                                .disabled(saveDisabled).opacity(saveDisabled ? Layout.disabledOpacity : Layout.enabledOpacity)
                        }
                    }.padding(Layout.gap).background(Color.white).overlay(alignment: .top) { Divider() }
                }
                .navigationTitle(action.label).navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button(Copy.close) { requestLeaving(.close) }.disabled(isSaving) } }
        }.foregroundStyle(Color.ufitInk).tint(Color.ufitInk).background(Color.white)
            .interactiveDismissDisabled(hasChanges || isSaving)
            .confirmationDialog(leaving == .refresh ? Copy.refreshTitle : Copy.discardTitle, isPresented: Binding(get: { leaving != nil }, set: { if !$0 { leaving = nil } }), titleVisibility: .visible, presenting: leaving) { action in
                Button(action == .refresh ? Copy.refreshDiscard : Copy.discard, role: .destructive) {
                    if action == .refresh { onRefresh() } else { onClose() }; leaving = nil
                }
                Button(Copy.keep, role: .cancel) { leaving = nil }
            }
    }
    private func requestLeaving(_ action: Leaving) {
        if hasChanges { leaving = action }
        else if action == .refresh { onRefresh() }
        else { onClose() }
    }
}
