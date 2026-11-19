import Foundation

extension UFitBrandOrderSummaryDTO {
    var presentation: UFitOrderSummary {
        let label = shipmentStatus == .failed ? status.label + UFitOrderFormatting.separator + String(localized: "Incident d’expédition") : status.label
        return .init(id: id, reference: orderNumber, date: createdAt.label, status: label,
            amount: UFitMoney.format(totalAmount, currency: currency), image: nil, pieces: UFitOrderFormatting.pieceCount(itemCount))
    }
}
extension UFitManagedShipment {
    var presentation: UFitShipmentPresentation {
        .init(status: status, carrier: carrier, trackingNumber: trackingNumber, trackingURL: trackingUrl.flatMap(URL.init(string:)),
            shippedAt: shippedAt, deliveredAt: deliveredAt, incidentReason: incidentReason, incidentAt: incidentAt)
    }
}
extension UFitBrandOrderDetailDTO {
    func presentation(stale: Bool) -> UFitBrandOrderPresentation {
        let commands: [UFitShipmentCommand]
        if let shipment, !stale { commands = actions.map { .init(action: $0, expectedVersion: shipment.version) } }
        else { commands = [] }
        return .init(summary: summary.presentation, items: items.map { item in
            .init(id: item.id, name: item.name, image: item.imageUrl,
                options: [item.size, item.color, String(localized: "Réf. \(item.sku)")].compactMap { $0 }.joined(separator: UFitOrderFormatting.separator),
                quantity: item.quantity, amount: UFitMoney.format(item.totalPrice, currency: summary.currency))
        }, address: UFitOrderFormatting.address(shippingAddress), phone: shippingAddress.phone,
            subtotal: UFitMoney.format(subtotalAmount, currency: summary.currency), shipping: UFitMoney.format(shippingAmount, currency: summary.currency),
            taxes: UFitMoney.format(taxAmount, currency: summary.currency), total: UFitMoney.format(summary.totalAmount, currency: summary.currency),
            shipment: cancellation == nil ? shipment?.presentation : nil, commands: commands,
            cancellationNote: cancellation.map { UFitCancellationCopy.note(reason: $0.reason, outcome: $0.outcome, refundState: $0.refund?.state, providerStatus: $0.refund?.providerStatus,
                total: UFitMoney.format(summary.totalAmount, currency: summary.currency), professional: true) })
    }
}
