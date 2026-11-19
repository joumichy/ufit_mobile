import Foundation

enum UFitOrderPresentationAdapter {
    static func summary(_ order: UFitOrderDTO) -> UFitOrderSummary {
        let count = order.items.reduce(Int.zero) { $0 + $1.quantity }
        return UFitOrderSummary(id: order.id, reference: order.orderNumber, date: UFitOrderFormatting.date(order.createdAt), status: order.status.label,
            amount: UFitMoney.format(order.totalAmount, currency: order.currency), image: order.items.first?.productSnapshot.imageUrl,
            pieces: UFitOrderFormatting.pieceCount(count))
    }
    static func detail(_ order: UFitOrderDTO) -> UFitOrderDetailPresentation {
        let total = UFitMoney.format(order.totalAmount, currency: order.currency)
        let address = UFitOrderFormatting.address(order.shippingAddress)
        let note = order.cancellation.map {
            UFitCancellationCopy.note(reason: $0.reason, outcome: $0.outcome, refundState: $0.refund?.state, providerStatus: $0.refund?.providerStatus, total: total)
        }
        return UFitOrderDetailPresentation(reference: order.orderNumber, date: UFitOrderFormatting.date(order.createdAt), status: order.status.label,
            items: order.items.map { item in UFitOrderPiece(id: item.id, name: item.productSnapshot.name, image: item.productSnapshot.imageUrl,
                options: [item.productSnapshot.size, item.productSnapshot.color].compactMap { $0 }.joined(separator: UFitOrderFormatting.separator),
                quantity: item.quantity, amount: UFitMoney.format(item.totalPrice, currency: order.currency)) },
            address: address, subtotal: UFitMoney.format(order.subtotalAmount, currency: order.currency), shipping: UFitMoney.format(order.shippingAmount, currency: order.currency),
            taxes: UFitMoney.format(order.taxAmount, currency: order.currency), total: total, returnPolicy: order.commerceSnapshot?.returnPolicy,
            shipment: order.shipment.flatMap { value in
                order.cancellation != nil || value.status == .cancelled ? nil : UFitShipmentPresentation(status: value.status, carrier: value.carrier, trackingNumber: value.trackingNumber,
                    trackingURL: value.trackingUrl.flatMap(URL.init(string:)), shippedAt: value.shippedAt.flatMap { UFitTimestamp(isoString: $0) },
                    deliveredAt: value.deliveredAt.flatMap { UFitTimestamp(isoString: $0) }, incidentReason: value.incidentReason, incidentAt: value.incidentAt)
            },
            cancellationNote: note, cancellationPrompt: order.status == .paid ? String(localized: "Le remboursement de \(total) sera demandé sur le moyen de paiement utilisé.") : String(localized: "Le paiement en attente sera interrompu."),
            cancellationPending: order.cancellation?.status == .requested, canCancel: order.actions.cancel, canResumePayment: order.actions.resumePayment,
            canRetryRefund: order.status == .cancelled && order.cancellation?.refund?.providerStatus == .cancelled)
    }
}
