import SwiftUI

struct UFitOrderDetailContent: View {
    let order: UFitOrderDetailPresentation?
    let isBusy: Bool
    let message: String?
    let onBack: () -> Void
    let onRefresh: () -> Void
    let onPay: () -> Void
    let onCancel: () -> Void
    @State private var confirmingCancellation = false
    private enum Copy {
        static let title = String(localized: "Ma commande")
        static let refresh = String(localized: "Actualiser")
        static let resume = String(localized: "Reprendre le paiement")
        static let cancel = String(localized: "Annuler la commande")
        static let confirmCancel = String(localized: "Confirmer l’annulation")
        static let continueCancel = String(localized: "Reprendre l’annulation")
        static let keep = String(localized: "Conserver la commande")
        static let unavailable = String(localized: "Commande indisponible")
        static let bag = "bag"
        static let address = String(localized: "Livraison")
        static let tracking = String(localized: "Suivi de l’expédition")
        static let openTracking = String(localized: "Suivre mon colis")
        static let subtotal = String(localized: "Pièces")
        static let shipping = String(localized: "Frais de livraison")
        static let taxes = String(localized: "Taxes ajoutées")
        static let total = String(localized: "Total")
        static let returns = String(localized: "Retours")
    }
    private enum Layout { static let spacing: CGFloat = 24; static let rowSpacing: CGFloat = 16; static let bottom: CGFloat = 110; static let imageWidth: CGFloat = 72; static let imageHeight: CGFloat = 94; static let touch: CGFloat = 44; static let inline: CGFloat = 8 }
    var body: some View {
        VStack(spacing: .zero) {
            DetailHeader(onBack: onBack) {
                if isBusy { ProgressView().frame(minWidth: Layout.touch, minHeight: Layout.touch) }
                else { Button(Copy.refresh, action: onRefresh).frame(minHeight: Layout.touch) }
            }
            if let message { Text(message).font(.callout).foregroundStyle(Color.ufitMuted).padding(.horizontal, Layout.spacing).padding(.top, Layout.rowSpacing) }
            ScrollView {
                VStack(alignment: .leading, spacing: Layout.spacing) {
                    if let order { detail(order) }
                    else if !isBusy { ContentUnavailableView(Copy.unavailable, systemImage: Copy.bag) }
                }.padding(Layout.spacing).padding(.bottom, Layout.bottom)
            }.refreshable { onRefresh() }.id(order?.status)
        }.foregroundStyle(Color.ufitInk).background(Color.white)
        .confirmationDialog(Copy.cancel, isPresented: $confirmingCancellation, titleVisibility: .visible) {
            Button(Copy.confirmCancel, role: .destructive, action: onCancel)
            Button(Copy.keep, role: .cancel) {}
        } message: { if let order { Text(order.cancellationPrompt) } }
    }
    private func detail(_ order: UFitOrderDetailPresentation) -> some View {
        VStack(alignment: .leading, spacing: Layout.spacing) {
            VStack(alignment: .leading, spacing: Layout.inline) {
                Text(order.reference).font(.title2.weight(.semibold))
                Text(order.date).font(.subheadline).foregroundStyle(Color.ufitMuted)
                Text(order.status).font(.headline)
            }
            if let note = order.cancellationNote { Text(note).font(.callout).foregroundStyle(Color.ufitMuted) }
            if order.canResumePayment {
                Button(action: onPay) { Text(Copy.resume).frame(maxWidth: .infinity) }.buttonStyle(PrimaryButtonStyle()).disabled(isBusy)
            }
            ForEach(order.items) { item in itemRow(item) }
            Divider()
            VStack(spacing: Layout.rowSpacing) {
                amount(Copy.subtotal, order.subtotal)
                amount(Copy.shipping, order.shipping)
                amount(Copy.taxes, order.taxes)
                Divider()
                amount(Copy.total, order.total).fontWeight(.semibold)
            }
            Divider()
            VStack(alignment: .leading, spacing: Layout.inline) {
                Text(Copy.address).font(.headline)
                ForEach(Array(order.address.enumerated()), id: \.offset) { _, line in Text(line).font(.subheadline) }
            }
            if let status = order.shipmentStatus {
                VStack(alignment: .leading, spacing: Layout.rowSpacing) {
                    Text(Copy.tracking).font(.headline)
                    Text(status)
                    if let tracking = order.trackingNumber { Text(tracking).font(.subheadline) }
                    if let url = order.trackingURL { Link(Copy.openTracking, destination: url).frame(minHeight: Layout.touch) }
                }
            }
            if let policy = order.returnPolicy {
                VStack(alignment: .leading, spacing: Layout.inline) { Text(Copy.returns).font(.headline); Text(policy).font(.callout).foregroundStyle(Color.ufitMuted) }
            }
            if order.canCancel {
                Button(order.cancellationPending ? Copy.continueCancel : Copy.cancel, role: .destructive) {
                    if order.cancellationPending { onCancel() } else { confirmingCancellation = true }
                }.frame(minHeight: Layout.touch).disabled(isBusy)
            }
        }
    }
    private func amount(_ label: String, _ amount: String) -> some View { HStack { Text(label); Spacer(); Text(amount) } }
    private func itemRow(_ item: UFitOrderPiece) -> some View {
        HStack(alignment: .top, spacing: Layout.rowSpacing) {
            if let image = item.image { FashionImage(source: image).frame(width: Layout.imageWidth, height: Layout.imageHeight).clipped() }
            VStack(alignment: .leading, spacing: Layout.inline) {
                Text(item.name).font(.headline)
                Text(item.options).font(.subheadline).foregroundStyle(Color.ufitMuted)
                Text(String(localized: "Quantité : \(item.quantity)")).font(.subheadline)
                Text(item.amount).font(.subheadline.weight(.medium))
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
