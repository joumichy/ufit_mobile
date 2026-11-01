import SwiftUI

private enum OrderContentLayout {
    static let gap: CGFloat = 16; static let small: CGFloat = 8; static let imageWidth: CGFloat = 72; static let imageHeight: CGFloat = 94; static let touch: CGFloat = 44
}
struct UFitOrderPieceContent: View {
    let item: UFitOrderPiece
    var body: some View {
        HStack(alignment: .top, spacing: OrderContentLayout.gap) {
            if let image = item.image { FashionImage(source: image).frame(width: OrderContentLayout.imageWidth, height: OrderContentLayout.imageHeight).clipped() }
            VStack(alignment: .leading, spacing: OrderContentLayout.small) {
                Text(item.name).font(.headline)
                Text(item.options).font(.subheadline).foregroundStyle(Color.ufitMuted)
                Text(String(localized: "Quantité : \(item.quantity)")).font(.subheadline)
                Text(item.amount).font(.subheadline.weight(.medium))
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
struct UFitOrderAmountsContent: View {
    let subtotal: String; let shipping: String; let taxes: String; let total: String
    private enum Copy {
        static let subtotal = String(localized: "Pièces"); static let shipping = String(localized: "Frais de livraison")
        static let taxes = String(localized: "Taxes ajoutées"); static let total = String(localized: "Total")
    }
    var body: some View {
        VStack(spacing: OrderContentLayout.gap) {
            amount(Copy.subtotal, subtotal); amount(Copy.shipping, shipping); amount(Copy.taxes, taxes)
            Divider(); amount(Copy.total, total).fontWeight(.semibold)
        }
    }
    private func amount(_ label: String, _ value: String) -> some View { HStack { Text(label); Spacer(); Text(value) } }
}
struct UFitOrderAddressContent: View {
    let lines: [String]
    var phone: String?
    private enum Copy { static let title = String(localized: "Livraison") }
    var body: some View {
        VStack(alignment: .leading, spacing: OrderContentLayout.small) {
            Text(Copy.title).font(.headline)
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in Text(line).font(.subheadline) }
            if let phone, !phone.isEmpty { Text(phone).font(.subheadline) }
        }
    }
}
struct UFitOrderTrackingContent: View {
    let shipment: UFitShipmentPresentation
    private enum Copy {
        static let title = String(localized: "Suivi de l’expédition"); static let follow = String(localized: "Suivre le colis")
        static let incident = String(localized: "Incident en cours"); static let lastIncident = String(localized: "Dernier incident")
    }
    var body: some View {
        VStack(alignment: .leading, spacing: OrderContentLayout.gap) {
            Text(Copy.title).font(.headline)
            Text(shipment.status.label)
            if let carrier = shipment.carrier { Text(carrier).font(.subheadline) }
            if let number = shipment.trackingNumber { Text(number).font(.subheadline).textSelection(.enabled) }
            if let date = shipment.shippedDate { Text(String(localized: "Expédition : \(date)")).font(.subheadline).foregroundStyle(Color.ufitMuted) }
            if let date = shipment.deliveredDate { Text(String(localized: "Livraison : \(date)")).font(.subheadline).foregroundStyle(Color.ufitMuted) }
            if let url = shipment.trackingURL { Link(Copy.follow, destination: url).frame(minHeight: OrderContentLayout.touch) }
            if let reason = shipment.incidentReason {
                VStack(alignment: .leading, spacing: OrderContentLayout.small) {
                    Text(shipment.status == .failed ? Copy.incident : Copy.lastIncident).font(.headline)
                    Text(reason).font(.callout).fixedSize(horizontal: false, vertical: true)
                    if let date = shipment.incidentDate { Text(date).font(.caption).foregroundStyle(Color.ufitMuted) }
                }
            }
        }
    }
}
