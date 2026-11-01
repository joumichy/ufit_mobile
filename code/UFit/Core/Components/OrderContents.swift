import SwiftUI

private enum OrderContentLayout {
    static let gap: CGFloat = UFitSpace.md; static let small: CGFloat = UFitSpace.xs; static let imageWidth: CGFloat = 72; static let imageHeight: CGFloat = 94; static let touch: CGFloat = UFitControlSize.touch
}
struct UFitOrderPieceContent: View {
    let item: UFitOrderPiece
    var body: some View {
        HStack(alignment: .top, spacing: OrderContentLayout.gap) {
            if let image = item.image { FashionImage(source: image).frame(width: OrderContentLayout.imageWidth, height: OrderContentLayout.imageHeight).clipped() }
            VStack(alignment: .leading, spacing: OrderContentLayout.small) {
                Text(item.name).font(UFitTypography.headline)
                Text(item.options).font(UFitTypography.subheadline).foregroundStyle(Color.ufitSecondaryText)
                Text(String(localized: "Quantité : \(item.quantity)")).font(UFitTypography.subheadline)
                Text(item.amount).font(UFitTypography.subheadline.weight(.medium))
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
            Text(Copy.title).font(UFitTypography.headline)
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in Text(line).font(UFitTypography.subheadline) }
            if let phone, !phone.isEmpty { Text(phone).font(UFitTypography.subheadline) }
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
            Text(Copy.title).font(UFitTypography.headline)
            Text(shipment.status.label)
            if let carrier = shipment.carrier { Text(carrier).font(UFitTypography.subheadline) }
            if let number = shipment.trackingNumber { Text(number).font(UFitTypography.subheadline).textSelection(.enabled) }
            if let date = shipment.shippedDate { Text(String(localized: "Expédition : \(date)")).font(UFitTypography.subheadline).foregroundStyle(Color.ufitSecondaryText) }
            if let date = shipment.deliveredDate { Text(String(localized: "Livraison : \(date)")).font(UFitTypography.subheadline).foregroundStyle(Color.ufitSecondaryText) }
            if let url = shipment.trackingURL { Link(Copy.follow, destination: url).frame(minHeight: OrderContentLayout.touch) }
            if let reason = shipment.incidentReason {
                VStack(alignment: .leading, spacing: OrderContentLayout.small) {
                    Text(shipment.status == .failed ? Copy.incident : Copy.lastIncident).font(UFitTypography.headline)
                    Text(reason).font(UFitTypography.callout).fixedSize(horizontal: false, vertical: true)
                    if let date = shipment.incidentDate { Text(date).font(UFitTypography.caption).foregroundStyle(Color.ufitSecondaryText) }
                }
            }
        }
    }
}

struct UFitLabeledValue<Content: View>: View {
    let title: String
    let content: Content
    init(_ title: String, @ViewBuilder content: () -> Content) { self.title = title; self.content = content() }
    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: UFitSpace.md) { Text(title).foregroundStyle(Color.ufitSecondaryText); Spacer(minLength: UFitSpace.xs); content }
            VStack(alignment: .leading, spacing: UFitSpace.xxs) { Text(title).foregroundStyle(Color.ufitSecondaryText); content }
        }.fixedSize(horizontal: false, vertical: true).accessibilityElement(children: .combine)
    }
}
extension UFitLabeledValue where Content == Text {
    init(_ title: String, value: String) { self.init(title) { Text(value) } }
}
