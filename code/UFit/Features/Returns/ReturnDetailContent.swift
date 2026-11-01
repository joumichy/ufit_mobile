import SwiftUI

struct UFitReturnDetailContent: View {
    let detail: UFitReturnDetailPresentation?
    let isLoading: Bool
    let activeAction: UFitReturnAction?
    let message: String?
    let onBack: () -> Void
    let onRefresh: () -> Void
    let onCommand: (UFitReturnCommand) -> Void
    @State private var confirming: UFitReturnCommand?
    private enum Copy {
        static let title = String(localized: "Dossier de retour"); static let refresh = String(localized: "Actualiser le dossier")
        static let loading = String(localized: "Chargement du retour"); static let unavailable = String(localized: "Retour indisponible")
        static let retry = String(localized: "Réessayer"); static let confirm = String(localized: "Confirmer"); static let keep = String(localized: "Revenir au dossier")
        static let reason = String(localized: "Motif du retour"); static let conditions = String(localized: "Conditions de la marque à l’achat")
        static let brandDecision = String(localized: "Décision de la marque"); static let adminDecision = String(localized: "Décision de l’administration")
        static let approved = String(localized: "Retour autorisé"); static let rejected = String(localized: "Retour refusé")
        static let dispute = String(localized: "Demande d’arbitrage"); static let instructions = String(localized: "Instructions de retour")
        static let tracking = String(localized: "Colis de retour"); static let follow = String(localized: "Suivre le colis de retour")
        static let receipt = String(localized: "Pièces reçues"); static let amounts = String(localized: "Montant du remboursement")
        static let merchandise = String(localized: "Pièces retournées"); static let shipping = String(localized: "Livraison initiale remboursée")
        static let taxes = String(localized: "Taxes remboursées"); static let total = String(localized: "Total remboursable")
    }
    private enum Layout {
        static let page: CGFloat = 24; static let gap: CGFloat = 16; static let small: CGFloat = 8; static let touch: CGFloat = 44
        static let singlePiece = 1; static let disabledOpacity = 0.4; static let enabledOpacity = 1.0
    }
    private enum Icon { static let refresh = "arrow.clockwise"; static let unavailable = "shippingbox" }
    private var locked: Bool { isLoading || activeAction != nil }
    private var primary: UFitReturnCommand? { detail?.commands.first { $0.action.isPrimary } }
    var body: some View {
        VStack(spacing: .zero) {
            DetailHeader(title: Copy.title, onBack: onBack) {
                if isLoading { ProgressView().frame(width: Layout.touch, height: Layout.touch) }
                else { Button(action: onRefresh) { Image(systemName: Icon.refresh).frame(width: Layout.touch, height: Layout.touch) }.accessibilityLabel(Copy.refresh) }
            }.disabled(activeAction != nil)
            if let message { Text(message).font(.callout).padding(.horizontal, Layout.page).padding(.top, Layout.gap) }
            ScrollView {
                VStack(alignment: .leading, spacing: Layout.page) {
                    if let detail {
                        VStack(alignment: .leading, spacing: Layout.small) {
                            Text(detail.summary.orderNumber).font(.title2.weight(.semibold))
                            Text(detail.summary.date).font(.subheadline).foregroundStyle(Color.ufitMuted)
                            Text(detail.summary.status.label).font(.headline)
                            Text(String(localized: "Demande possible jusqu’au \(detail.deadline)")).font(.caption).foregroundStyle(Color.ufitMuted)
                        }
                        section(Copy.reason, detail.reason)
                        ForEach(detail.items) { UFitOrderPieceContent(item: $0) }
                        Divider()
                        VStack(alignment: .leading, spacing: Layout.gap) {
                            Text(Copy.amounts).font(.headline)
                            amount(Copy.merchandise, detail.amounts.merchandise); amount(Copy.shipping, detail.amounts.shipping); amount(Copy.taxes, detail.amounts.taxes)
                            Divider(); amount(Copy.total, detail.amounts.total).fontWeight(.semibold)
                            Text(detail.amounts.policy.explanation).font(.footnote).foregroundStyle(Color.ufitMuted)
                            if let note = detail.refundNote { Text(note).font(.callout) }
                            if let date = detail.refundDate { Text(String(localized: "Remboursement confirmé le \(date)")).font(.subheadline) }
                        }
                        section(Copy.conditions, detail.returnPolicy)
                        if let decision = detail.brandDecision { decisionContent(Copy.brandDecision, decision) }
                        if let reason = detail.disputeReason { section(Copy.dispute, reason, date: detail.disputeDate) }
                        if let decision = detail.adminDecision { decisionContent(Copy.adminDecision, decision) }
                        if let tracking = detail.tracking {
                            VStack(alignment: .leading, spacing: Layout.small) {
                                Text(Copy.tracking).font(.headline); Text(tracking.carrier); Text(tracking.trackingNumber).textSelection(.enabled)
                                Text(String(localized: "Envoi déclaré le \(tracking.sentDate)")).font(.caption).foregroundStyle(Color.ufitMuted)
                                if let url = tracking.trackingURL { Link(Copy.follow, destination: url).frame(minHeight: Layout.touch) }
                            }
                        }
                        if let date = detail.receiptDate {
                            VStack(alignment: .leading, spacing: Layout.small) {
                                Text(Copy.receipt).font(.headline); Text(date).font(.subheadline)
                                ForEach(detail.items) { item in
                                    if let quantity = detail.restocked[item.id] { Text(quantity == Layout.singlePiece ? String(localized: "\(item.name) : 1 pièce remise en stock") : String(localized: "\(item.name) : \(quantity) pièces remises en stock")).font(.subheadline) }
                                }
                            }
                        }
                        ForEach(detail.commands.filter { !$0.action.isPrimary }) { command in action(command, primary: false) }
                    } else if isLoading { ProgressView(Copy.loading).frame(maxWidth: .infinity) }
                    else { ContentUnavailableView(Copy.unavailable, systemImage: Icon.unavailable); Button(Copy.retry, action: onRefresh).frame(minHeight: Layout.touch) }
                }.padding(Layout.page).frame(maxWidth: .infinity, alignment: .leading)
            }
        }.safeAreaInset(edge: .bottom, spacing: .zero) {
            if let primary { action(primary, primary: true).padding(Layout.gap).background(Color.white).overlay(alignment: .top) { Divider() } }
        }.foregroundStyle(Color.ufitInk).tint(Color.ufitInk).background(Color.white)
            .confirmationDialog(confirming?.action.label ?? Copy.confirm, isPresented: Binding(get: { confirming != nil }, set: { if !$0 { confirming = nil } }), titleVisibility: .visible, presenting: confirming) { command in
                Button(Copy.confirm) { onCommand(command); confirming = nil }; Button(Copy.keep, role: .cancel) { confirming = nil }
            } message: { Text($0.action.confirmation) }
    }
    private func amount(_ label: String, _ value: String) -> some View { HStack(alignment: .firstTextBaseline) { Text(label); Spacer(); Text(value) } }
    private func section(_ title: String, _ text: String, date: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: Layout.small) { Text(title).font(.headline); Text(text).font(.callout); if let date { Text(date).font(.caption).foregroundStyle(Color.ufitMuted) } }
    }
    private func decisionContent(_ title: String, _ decision: UFitReturnDecisionPresentation) -> some View {
        VStack(alignment: .leading, spacing: Layout.small) {
            Text(title).font(.headline); Text(decision.accepted ? Copy.approved : Copy.rejected).font(.subheadline.weight(.medium))
            Text(decision.date).font(.caption).foregroundStyle(Color.ufitMuted)
            if let reason = decision.reason { Text(reason).font(.callout) }
            if let instructions = decision.instructions { Text(Copy.instructions).font(.subheadline.weight(.medium)); Text(instructions).font(.callout) }
        }
    }
    @ViewBuilder private func action(_ command: UFitReturnCommand, primary: Bool) -> some View {
        let button = Button {
            if command.action.requiresForm { onCommand(command) } else { confirming = command }
        } label: {
            Group { if activeAction == command.action { ProgressView(command.action.label) } else { Text(command.action.label).multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true) } }.padding(.horizontal, Layout.gap).frame(maxWidth: .infinity, minHeight: Layout.touch)
        }.disabled(locked).opacity(locked && activeAction != command.action ? Layout.disabledOpacity : Layout.enabledOpacity)
        if primary { button.buttonStyle(PrimaryButtonStyle()) } else { button.buttonStyle(.plain) }
    }
}
