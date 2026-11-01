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
        let note: String?
        if order.cancellation?.reason == .stockUnavailable {
            switch order.cancellation?.outcome {
            case .refunded: note = String(localized: "Une pièce est devenue indisponible après le paiement. \(total) ont été remboursés sur votre moyen de paiement.")
            case .notCharged: note = String(localized: "Une pièce n’est plus disponible. Aucun paiement n’a été débité.")
            case nil: note = String(localized: "Une pièce est devenue indisponible après le paiement. Le remboursement est en cours de traitement.")
            }
        } else {
            switch order.cancellation?.outcome {
            case .refunded: note = String(localized: "\(total) ont été remboursés sur votre moyen de paiement.")
            case .notCharged: note = String(localized: "Aucun paiement n’a été débité.")
            case nil: note = nil
            }
        }
        return UFitOrderDetailPresentation(reference: order.orderNumber, date: UFitOrderFormatting.date(order.createdAt), status: order.status.label,
            items: order.items.map { item in UFitOrderPiece(id: item.id, name: item.productSnapshot.name, image: item.productSnapshot.imageUrl,
                options: [item.productSnapshot.size, item.productSnapshot.color].compactMap { $0 }.joined(separator: UFitOrderFormatting.separator),
                quantity: item.quantity, amount: UFitMoney.format(item.totalPrice, currency: order.currency)) },
            address: address, subtotal: UFitMoney.format(order.subtotalAmount, currency: order.currency), shipping: UFitMoney.format(order.shippingAmount, currency: order.currency),
            taxes: UFitMoney.format(order.taxAmount, currency: order.currency), total: total, returnPolicy: order.commerceSnapshot?.returnPolicy,
            shipment: order.shipment.flatMap { value in
                value.status == .cancelled ? nil : UFitShipmentPresentation(status: value.status, carrier: value.carrier, trackingNumber: value.trackingNumber,
                    trackingURL: value.trackingUrl.flatMap(URL.init(string:)), shippedAt: value.shippedAt.flatMap { UFitTimestamp(isoString: $0) },
                    deliveredAt: value.deliveredAt.flatMap { UFitTimestamp(isoString: $0) }, incidentReason: value.incidentReason, incidentAt: value.incidentAt)
            },
            cancellationNote: note, cancellationPrompt: order.status == .paid ? String(localized: "\(total) seront remboursés sur le moyen de paiement utilisé.") : String(localized: "Le paiement en attente sera interrompu."),
            cancellationPending: order.status == .cancelling, canCancel: order.actions.cancel, canResumePayment: order.actions.resumePayment)
    }
}
