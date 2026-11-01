import SwiftUI

struct UFitBrandOrderContent: View {
    let order: UFitBrandOrderPresentation?
    let isLoading: Bool
    let activeAction: UFitShipmentAction?
    let message: String?
    let onBack: () -> Void
    let onRefresh: () -> Void
    let onCommand: (UFitShipmentCommand) -> Void
    @State private var confirming: UFitShipmentCommand?
    private enum Copy {
        static let title = String(localized: "Commande"); static let refresh = String(localized: "Actualiser la commande")
        static let loading = String(localized: "Chargement de la commande"); static let unavailable = String(localized: "Commande indisponible")
        static let retry = String(localized: "Réessayer"); static let confirm = String(localized: "Confirmer")
        static let keep = String(localized: "Revenir à la commande")
    }
    private enum Layout {
        static let page: CGFloat = 24; static let gap: CGFloat = 16; static let small: CGFloat = 8; static let touch: CGFloat = 44
        static let disabledOpacity = 0.4; static let enabledOpacity = 1.0
    }
    private enum Icon { static let refresh = "arrow.clockwise"; static let unavailable = "bag" }
    private var recordLocked: Bool { isLoading || activeAction != nil }
    private var primary: UFitShipmentCommand? { order?.commands.first(where: { $0.action.isPrimary }) }
    var body: some View {
        VStack(spacing: .zero) {
            DetailHeader(title: Copy.title, onBack: onBack) {
                if isLoading { ProgressView().frame(width: Layout.touch, height: Layout.touch) }
                else { Button(action: onRefresh) { Image(systemName: Icon.refresh).frame(width: Layout.touch, height: Layout.touch) }.accessibilityLabel(Copy.refresh) }
            }.disabled(activeAction != nil)
            if let message { Text(message).font(.callout).foregroundStyle(Color.ufitMuted).padding(.horizontal, Layout.page).padding(.top, Layout.gap) }
            ScrollView {
                VStack(alignment: .leading, spacing: Layout.page) {
                    if let order {
                        VStack(alignment: .leading, spacing: Layout.small) {
                            Text(order.summary.reference).font(.title2.weight(.semibold))
                            Text(order.summary.date).font(.subheadline).foregroundStyle(Color.ufitMuted)
                            Text(order.summary.status).font(.headline)
                        }
                        UFitOrderAddressContent(lines: order.address, phone: order.phone)
                        Divider()
                        ForEach(order.items) { UFitOrderPieceContent(item: $0) }
                        Divider()
                        UFitOrderAmountsContent(subtotal: order.subtotal, shipping: order.shipping, taxes: order.taxes, total: order.total)
                        if let shipment = order.shipment { Divider(); UFitOrderTrackingContent(shipment: shipment) }
                        ForEach(order.commands.filter { !$0.action.isPrimary }) { command in action(command, primary: false) }
                    } else if isLoading { ProgressView(Copy.loading).frame(maxWidth: .infinity) }
                    else {
                        ContentUnavailableView(Copy.unavailable, systemImage: Icon.unavailable)
                        Button(Copy.retry, action: onRefresh).frame(minHeight: Layout.touch)
                    }
                }.padding(Layout.page).frame(maxWidth: .infinity, alignment: .leading)
            }
        }.safeAreaInset(edge: .bottom, spacing: .zero) {
            if let primary { action(primary, primary: true).padding(Layout.gap).background(Color.white).overlay(alignment: .top) { Divider() } }
        }.foregroundStyle(Color.ufitInk).tint(Color.ufitInk).background(Color.white)
            .confirmationDialog(confirming?.action.label ?? Copy.confirm, isPresented: Binding(get: { confirming != nil }, set: { if !$0 { confirming = nil } }), titleVisibility: .visible, presenting: confirming) { command in
                Button(Copy.confirm) { onCommand(command); confirming = nil }
                Button(Copy.keep, role: .cancel) { confirming = nil }
            } message: { command in Text(command.action.confirmation) }
    }
    @ViewBuilder private func action(_ command: UFitShipmentCommand, primary: Bool) -> some View {
        let button = Button {
            if command.action.requiresForm { onCommand(command) } else { confirming = command }
        } label: {
            Group {
                if activeAction == command.action { ProgressView(command.action.label) }
                else { Text(command.action.label) }
            }.frame(maxWidth: .infinity, minHeight: Layout.touch)
        }.disabled(recordLocked).opacity(recordLocked && activeAction != command.action ? Layout.disabledOpacity : Layout.enabledOpacity)
        if primary { button.buttonStyle(PrimaryButtonStyle()) } else { button.buttonStyle(.plain) }
    }
}
