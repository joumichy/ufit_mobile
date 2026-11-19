import SwiftUI

struct UFitAdminOrderDetailContent: View {
    let store: UFitAdminOrderDetailStore
    let onBack: () -> Void; let onReturns: () -> Void
    let onSettlement: (String) -> Void
    private var document: UFitAdminOrderDetail? { store.collection.canRead ? store.document : nil }
    var body: some View {
        VStack(spacing: .zero) {
            DetailHeader(title: UFitAdminOrdersCopy.detail, onBack: onBack)
            ScrollView {
                VStack(alignment: .leading, spacing: UFitSpace.xl) {
                    if let message = store.message {
                        UFitNotice(message: message, kind: .error)
                        UFitActionButton(title: UFitAdminOrdersCopy.retry, kind: .secondary, disabled: store.isLoading) { Task { await store.load() } }
                    }
                    if let document { detail(document) }
                    else if store.isLoading { UFitLoading(UFitAdminOrdersCopy.loadingOrder).frame(maxWidth: .infinity) }
                }.padding(UFitSpace.page).frame(maxWidth: .infinity, alignment: .leading)
            }.ufitRefreshable(isEnabled: !store.isLoading, title: UFitAdminOrdersCopy.refresh) { await store.load() }
        }.ufitButtonStyle(.text).foregroundStyle(Color.ufitInk).background(Color.ufitCanvas)
            .task { await store.load() }.onDisappear { store.cancelLoading() }
    }
    private func detail(_ document: UFitAdminOrderDetail) -> some View {
        let order = UFitOrderPresentationAdapter.detail(document.order)
        return VStack(alignment: .leading, spacing: UFitSpace.xl) {
            VStack(alignment: .leading, spacing: UFitSpace.sm) {
                Text(order.reference).font(UFitTypography.title2).accessibilityAddTraits(.isHeader)
                Text(document.brand.name).font(UFitTypography.headline)
                Text(order.date).font(UFitTypography.caption).foregroundStyle(Color.ufitSecondaryText)
                HStack(alignment: .firstTextBaseline) { Text(order.status).font(UFitTypography.headline); Spacer(); Text(order.total).font(UFitTypography.title2) }
            }
            if let note = order.cancellationNote { UFitNotice(message: note, kind: .information) }
            if document.returnCount > .zero {
                UFitExperienceActionRow(title: UFitAdminOrdersCopy.returns, count: document.returnCount, systemImage: ReturnIcon.returns, action: onReturns)
                Divider()
            }
            VStack(alignment: .leading, spacing: UFitSpace.md) {
                UFitEditorialHeading(title: UFitAdminOrdersCopy.payments, editorial: false)
                if document.payments.isEmpty { Text(UFitAdminOrdersCopy.noPaymentDetail).font(UFitTypography.callout).foregroundStyle(Color.ufitSecondaryText) }
                ForEach(document.payments) { payment in
                    VStack(alignment: .leading, spacing: UFitSpace.sm) {
                        HStack { Text(payment.status.label).font(UFitTypography.headline); Spacer(); Text(UFitMoney.format(payment.amount, currency: payment.currency)).font(UFitTypography.headline) }
                        Text(payment.createdAt.label).font(UFitTypography.caption).foregroundStyle(Color.ufitSecondaryText)
                        UFitDisclosure(UFitAdminOrdersCopy.paymentDetails) {
                            VStack(alignment: .leading, spacing: UFitSpace.sm) {
                                UFitLabeledValue(UFitAdminOrdersCopy.provider, value: payment.provider.label)
                                if let reference = payment.providerPaymentIntentId { Text(UFitAdminOrdersCopy.paymentReference).foregroundStyle(Color.ufitSecondaryText); Text(reference).fixedSize(horizontal: false, vertical: true) }
                                UFitLabeledValue(UFitAdminOrdersCopy.updatedAt, value: payment.updatedAt.label)
                            }.font(UFitTypography.callout)
                        }
                        UFitExperienceActionRow(title: UFitPaymentSettlementCopy.title, systemImage: UFitPaymentSettlementCopy.icon) { onSettlement(payment.id) }
                    }
                }
            }
            Divider()
            if let shipment = order.shipment { UFitOrderTrackingContent(shipment: shipment) }
            else { Text(UFitAdminOrdersCopy.noShipment).font(UFitTypography.callout).foregroundStyle(Color.ufitSecondaryText) }
            Divider()
            VStack(alignment: .leading, spacing: UFitSpace.md) {
                UFitEditorialHeading(title: UFitAdminOrdersCopy.contents, editorial: false)
                ForEach(order.items) { UFitOrderPieceContent(item: $0) }
                UFitOrderAmountsContent(subtotal: order.subtotal, shipping: order.shipping, taxes: order.taxes, total: order.total)
            }
            UFitDisclosure(UFitAdminOrdersCopy.address) { UFitOrderAddressContent(lines: order.address, phone: document.order.shippingAddress.phone) }
            if document.returnCount == .zero { UFitActionButton(title: UFitAdminOrdersCopy.returns, kind: .secondary, action: onReturns) }
            Text(UFitAdminOrdersCopy.observed(document.asOf)).font(UFitTypography.caption).foregroundStyle(Color.ufitSecondaryText)
        }
    }
    private enum ReturnIcon { static let returns = "arrow.uturn.backward" }
}
