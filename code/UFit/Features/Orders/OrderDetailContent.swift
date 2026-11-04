import SwiftUI

struct UFitOrderDetailContent: View {
    let order: UFitOrderDetailPresentation?
    let isBusy: Bool
    let message: String?
    let onBack: () -> Void
    let onRefresh: () -> Void
    let onPay: () -> Void
    let onCancel: () -> Void
    let onReturns: () -> Void
    var payment: UFitCustomerPaymentStatusDTO? = nil
    var paymentMessage: String? = nil
    var onRefundOrganization: (() -> Void)? = nil
    @State private var confirmingCancellation = false
    private enum Copy {
        static let title = String(localized: "Ma commande")
        static let refresh = String(localized: "Actualiser")
        static let resume = String(localized: "Reprendre le paiement")
        static let cancel = String(localized: "Annuler la commande")
        static let confirmCancel = String(localized: "Confirmer l’annulation")
        static let continueCancel = String(localized: "Reprendre l’annulation")
        static let retryRefund = String(localized: "Reprendre le remboursement")
        static let keep = String(localized: "Conserver la commande")
        static let unavailable = String(localized: "Commande indisponible")
        static let bag = "bag"
        static let returns = String(localized: "Retours")
        static let returnDossiers = String(localized: "Retours et remboursements")
    }
    private enum Layout { static let spacing: CGFloat = UFitSpace.xl; static let rowSpacing: CGFloat = UFitSpace.md; static let bottom: CGFloat = 110; static let touch: CGFloat = UFitControlSize.touch; static let inline: CGFloat = 8 }
    var body: some View {
        VStack(spacing: .zero) {
            DetailHeader(onBack: onBack) {
                if isBusy { UFitLoading().frame(minWidth: Layout.touch, minHeight: Layout.touch) }
                else { UFitButton(Copy.refresh, action: onRefresh).frame(minHeight: Layout.touch) }
            }
            if let message { Text(message).font(UFitTypography.callout).foregroundStyle(Color.ufitSecondaryText).padding(.horizontal, Layout.spacing).padding(.top, Layout.rowSpacing) }
            ScrollView {
                VStack(alignment: .leading, spacing: Layout.spacing) {
                    if let order { detail(order) }
                    else if !isBusy { UFitEmptyState(title: Copy.unavailable, symbol: Copy.bag) }
                }.padding(Layout.spacing).padding(.bottom, UFitSpace.xl)
            }.ufitRefreshable { onRefresh() }.id(order?.status)
        }.foregroundStyle(Color.ufitInk).background(Color.ufitCanvas)
        .ufitConfirmationDialog(Copy.cancel, isPresented: $confirmingCancellation, titleVisibility: .visible) {
            UFitButton(Copy.confirmCancel, role: .destructive, action: onCancel)
            UFitButton(Copy.keep, role: .cancel) {}
        } message: { if let order { Text(order.cancellationPrompt) } }
    }
    private func detail(_ order: UFitOrderDetailPresentation) -> some View {
        VStack(alignment: .leading, spacing: Layout.spacing) {
            VStack(alignment: .leading, spacing: Layout.inline) {
                Text(order.reference).font(UFitTypography.title2.weight(.semibold))
                Text(order.date).font(UFitTypography.subheadline).foregroundStyle(Color.ufitSecondaryText)
                Text(order.status).font(UFitTypography.headline)
            }
            if let note = order.cancellationNote { Text(note).font(UFitTypography.callout).foregroundStyle(Color.ufitSecondaryText) }
            if let onRefundOrganization {UFitButton(UFitRefundOrganizationCopy.follow, action: onRefundOrganization).ufitButtonStyle(.secondary).disabled(isBusy)}
            if order.needsPaymentStatus && (isBusy || payment != nil || paymentMessage != nil) {
                UFitCustomerPaymentStatusContent(payment: payment, isLoading: isBusy, message: paymentMessage)
            }
            if order.canResumePayment {
                UFitButton(action: onPay) { Text(Copy.resume).frame(maxWidth: .infinity) }.ufitButtonStyle(.primary).disabled(isBusy)
            }
            ForEach(order.items) { UFitOrderPieceContent(item: $0) }
            Divider()
            UFitOrderAmountsContent(subtotal: order.subtotal, shipping: order.shipping, taxes: order.taxes, total: order.total)
            Divider()
            UFitOrderAddressContent(lines: order.address)
            if let shipment = order.shipment { UFitOrderTrackingContent(shipment: shipment) }
            if let policy = order.returnPolicy {
                VStack(alignment: .leading, spacing: Layout.inline) { Text(Copy.returns).font(UFitTypography.headline); Text(policy).font(UFitTypography.callout).foregroundStyle(Color.ufitSecondaryText) }
            }
            UFitButton(Copy.returnDossiers, action: onReturns).frame(minHeight: Layout.touch).disabled(isBusy)
            if order.canCancel {
                UFitButton(order.canRetryRefund ? Copy.retryRefund : order.cancellationPending ? Copy.continueCancel : Copy.cancel, role: order.canRetryRefund ? nil : .destructive) {
                    if order.cancellationPending || order.canRetryRefund { onCancel() } else { confirmingCancellation = true }
                }.frame(minHeight: Layout.touch).disabled(isBusy)
            }
        }
    }
}
