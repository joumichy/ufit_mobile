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
        static let page: CGFloat = UFitSpace.xl; static let gap: CGFloat = UFitSpace.md; static let small: CGFloat = UFitSpace.xs; static let touch: CGFloat = UFitControlSize.touch
        static let disabledOpacity = 0.4; static let enabledOpacity = 1.0
    }
    private enum Icon { static let refresh = "arrow.clockwise"; static let unavailable = "bag" }
    private var recordLocked: Bool { isLoading || activeAction != nil }
    private var primary: UFitShipmentCommand? { order?.commands.first(where: { $0.action.isPrimary }) }
    var body: some View {
        VStack(spacing: .zero) {
            DetailHeader(title: Copy.title, onBack: onBack) {
                if isLoading { UFitLoading().frame(width: Layout.touch, height: Layout.touch) }
                else { UFitButton(action: onRefresh) { UFitIcon(systemName: Icon.refresh).frame(width: Layout.touch, height: Layout.touch) }.accessibilityLabel(Copy.refresh) }
            }.disabled(activeAction != nil)
            if let message { Text(message).font(UFitTypography.callout).foregroundStyle(Color.ufitSecondaryText).padding(.horizontal, Layout.page).padding(.top, Layout.gap) }
            ScrollView {
                VStack(alignment: .leading, spacing: Layout.page) {
                    if let order {
                        VStack(alignment: .leading, spacing: Layout.small) {
                            Text(order.summary.reference).font(UFitTypography.title2.weight(.semibold))
                            Text(order.summary.date).font(UFitTypography.subheadline).foregroundStyle(Color.ufitSecondaryText)
                            Text(order.summary.status).font(UFitTypography.headline)
                        }
                        if let note = order.cancellationNote { Text(note).font(UFitTypography.callout).foregroundStyle(Color.ufitSecondaryText) }
                        UFitOrderAddressContent(lines: order.address, phone: order.phone)
                        Divider()
                        ForEach(order.items) { UFitOrderPieceContent(item: $0) }
                        Divider()
                        UFitOrderAmountsContent(subtotal: order.subtotal, shipping: order.shipping, taxes: order.taxes, total: order.total)
                        if let shipment = order.shipment { Divider(); UFitOrderTrackingContent(shipment: shipment) }
                        ForEach(order.commands.filter { !$0.action.isPrimary }) { command in action(command, primary: false) }
                    } else if isLoading { UFitLoading(Copy.loading).frame(maxWidth: .infinity) }
                    else {
                        UFitEmptyState(title: Copy.unavailable, symbol: Icon.unavailable)
                        UFitButton(Copy.retry, action: onRefresh).frame(minHeight: Layout.touch)
                    }
                }.padding(Layout.page).frame(maxWidth: .infinity, alignment: .leading)
            }
        }.safeAreaInset(edge: .bottom, spacing: .zero) {
            if let primary { action(primary, primary: true).padding(Layout.gap).background(Color.ufitCanvas).overlay(alignment: .top) { Divider() } }
        }.foregroundStyle(Color.ufitInk).tint(Color.ufitInk).background(Color.ufitCanvas)
            .ufitConfirmationDialog(confirming?.action.label ?? Copy.confirm, isPresented: Binding(get: { confirming != nil }, set: { if !$0 { confirming = nil } }), titleVisibility: .visible, presenting: confirming) { command in
                UFitButton(Copy.confirm) { onCommand(command); confirming = nil }
                UFitButton(Copy.keep, role: .cancel) { confirming = nil }
            } message: { command in Text(command.action.confirmation) }
    }
    @ViewBuilder private func action(_ command: UFitShipmentCommand, primary: Bool) -> some View {
        let button = UFitButton {
            if command.action.requiresForm { onCommand(command) } else { confirming = command }
        } label: {
            Group {
                if activeAction == command.action { UFitLoading(command.action.label) }
                else { Text(command.action.label) }
            }.frame(maxWidth: .infinity, minHeight: Layout.touch)
        }.disabled(recordLocked).opacity(recordLocked && activeAction != command.action ? Layout.disabledOpacity : Layout.enabledOpacity)
        if primary { button.ufitButtonStyle(.primary) } else { button.ufitButtonStyle(.text) }
    }
}
