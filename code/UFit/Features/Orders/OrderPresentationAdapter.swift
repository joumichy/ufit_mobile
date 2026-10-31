import Foundation

enum UFitOrderPresentationAdapter {
    private enum Format { static let separator = " · "; static let single = 1; static let countryLocale = Locale(identifier: "fr") }
    private static func date(_ value: String) -> String {
        let parser = ISO8601DateFormatter()
        parser.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return parser.date(from: value)?.formatted(.dateTime.day().month(.wide).year().locale(Format.countryLocale)) ?? String()
    }
    static func summary(_ order: UFitOrderDTO) -> UFitOrderSummary {
        let count = order.items.reduce(Int.zero) { $0 + $1.quantity }
        return UFitOrderSummary(id: order.id, reference: order.orderNumber, date: date(order.createdAt), status: order.status.label,
            amount: UFitMoney.format(order.totalAmount, currency: order.currency), image: order.items.first?.productSnapshot.imageUrl,
            pieces: count == Format.single ? String(localized: "1 pièce") : String(localized: "\(count) pièces"))
    }
    static func detail(_ order: UFitOrderDTO) -> UFitOrderDetailPresentation {
        let total = UFitMoney.format(order.totalAmount, currency: order.currency)
        let country = Format.countryLocale.localizedString(forRegionCode: order.shippingAddress.country) ?? order.shippingAddress.country
        let address = [order.shippingAddress.fullName, order.shippingAddress.line1, order.shippingAddress.line2,
            order.shippingAddress.postalCode + " " + order.shippingAddress.city, country].compactMap { $0 }.filter { !$0.isEmpty }
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
        return UFitOrderDetailPresentation(reference: order.orderNumber, date: date(order.createdAt), status: order.status.label,
            items: order.items.map { item in UFitOrderPiece(id: item.id, name: item.productSnapshot.name, image: item.productSnapshot.imageUrl,
                options: [item.productSnapshot.size, item.productSnapshot.color].compactMap { $0 }.joined(separator: Format.separator),
                quantity: item.quantity, amount: UFitMoney.format(item.totalPrice, currency: order.currency)) },
            address: address, subtotal: UFitMoney.format(order.subtotalAmount, currency: order.currency), shipping: UFitMoney.format(order.shippingAmount, currency: order.currency),
            taxes: UFitMoney.format(order.taxAmount, currency: order.currency), total: total, returnPolicy: order.commerceSnapshot?.returnPolicy,
            shipmentStatus: order.shipment?.status == .cancelled ? nil : order.shipment?.status.label,
            trackingNumber: order.shipment?.trackingNumber, trackingURL: order.shipment?.trackingUrl.flatMap(URL.init(string:)),
            cancellationNote: note, cancellationPrompt: order.status == .paid ? String(localized: "\(total) seront remboursés sur le moyen de paiement utilisé.") : String(localized: "Le paiement en attente sera interrompu."),
            cancellationPending: order.status == .cancelling, canCancel: order.actions.cancel, canResumePayment: order.actions.resumePayment)
    }
}
