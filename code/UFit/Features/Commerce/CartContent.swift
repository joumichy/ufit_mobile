import SwiftUI

struct UFitCartContent: View {
    let lines: [UFitCartPresentationLine]
    let subtotal: String
    let isLoading: Bool
    let hasLoaded: Bool
    let loadError: String?
    let message: String?
    let onBack: () -> Void
    let onBrowse: () -> Void
    let onRefresh: () async -> Void
    let onQuantity: (String, Int) -> Void
    let onRemove: (String) -> Void
    var onCheckout: (() -> Void)?
    var checkoutRecovery: UFitCheckoutRecoveryNotice? = nil
    private enum Copy {
        static let title = String(localized: "Mon panier")
        static let empty = String(localized: "Votre panier est vide")
        static let emptyIcon = "bag"
        static let subtotal = String(localized: "Sous-total")
        static let checkout = String(localized: "Livraison et paiement")
        static let retry = String(localized: "Réessayer")
        static let browse = String(localized: "Découvrir les tenues")
        static let loading = String(localized: "Chargement du panier")
        static let failed = String(localized: "Panier indisponible")
        static let failureIcon = "wifi.exclamationmark"
    }
    private enum Layout { static let spacing: CGFloat = UFitSpace.xl }
    var body: some View {
        VStack(spacing: .zero) {
            DetailHeader(title: Copy.title, onBack: onBack)
            GeometryReader { viewport in
                ScrollView {
                    VStack(alignment: .leading, spacing: Layout.spacing) {
                        if let checkoutRecovery, let onCheckout { recovery(checkoutRecovery, onOpen: onCheckout) }
                        if lines.isEmpty { initialContent }
                        else {
                            if isLoading { UFitLoading(Copy.loading).frame(maxWidth: .infinity) }
                            if let loadError, !isLoading {
                                UFitNotice(message: loadError, kind: .error)
                                UFitActionButton(title: Copy.retry, kind: .secondary, action: refresh)
                            }
                            if let message { UFitNotice(message: message, kind: .error) }
                            ForEach(lines) { line in
                                UFitCartLineContent(line: line, onQuantity: { onQuantity(line.id, $0) }, onRemove: { onRemove(line.id) })
                                Divider()
                            }
                        }
                    }.padding(Layout.spacing).frame(minHeight: viewport.size.height, alignment: lines.isEmpty && checkoutRecovery == nil ? .center : .topLeading)
                }.ufitRefreshable { await onRefresh() }
            }
        }.safeAreaInset(edge: .bottom, spacing: .zero) {
            if !lines.isEmpty {
                VStack(spacing: UFitSpace.md) {
                    HStack { Text(Copy.subtotal); Spacer(); Text(subtotal).font(UFitTypography.headline) }
                    if let onCheckout, checkoutRecovery == nil { UFitActionButton(title: Copy.checkout, disabled: lines.contains { $0.isBusy || !$0.isAvailable }, action: onCheckout) }
                }.padding(UFitSpace.page).background(Color.ufitCanvas).overlay(alignment: .top) { Rectangle().fill(Color.ufitBorder).frame(height: UFitSpace.hairline) }
            }
        }.foregroundStyle(Color.ufitInk).background(Color.ufitCanvas)
    }
    @ViewBuilder private var initialContent: some View {
        if isLoading || (!hasLoaded && loadError == nil) { UFitLoading(Copy.loading).frame(maxWidth: .infinity) }
        else if let loadError {
            UFitEmptyState(title: Copy.failed, message: loadError, symbol: Copy.failureIcon,
                actionTitle: Copy.retry, action: refresh)
        } else {
            UFitEmptyState(title: Copy.empty, symbol: Copy.emptyIcon,
                actionTitle: Copy.browse, actionKind: checkoutRecovery == nil ? .primary : .secondary, action: onBrowse)
        }
    }
    private func recovery(_ notice: UFitCheckoutRecoveryNotice, onOpen: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: UFitSpace.md) {
            Text(UFitCheckoutRecoveryCopy.cartTitle).font(UFitTypography.headline)
            switch notice {
            case .pending(let amount):
                Text(UFitCheckoutRecoveryCopy.cartDetail).font(UFitTypography.callout).foregroundStyle(Color.ufitSecondaryText)
                HStack { Text(UFitCheckoutRecoveryCopy.amount); Spacer(); Text(amount).monospacedDigit() }.font(UFitTypography.subheadline)
            case .unavailable:
                Text(UFitCheckoutRecoveryCopy.localRead).font(UFitTypography.callout).foregroundStyle(Color.ufitSecondaryText)
            }
            UFitActionButton(title: notice.actionTitle, action: onOpen)
        }.padding(UFitSpace.lg).background(Color.ufitSecondary, in: RoundedRectangle(cornerRadius: UFitRadius.card))
    }
    private func refresh() { Task { await onRefresh() } }

}

private struct UFitCartLineContent: View {
    let line: UFitCartPresentationLine
    let onQuantity: (Int) -> Void
    let onRemove: () -> Void
    private enum Copy {
        static let quantity = String(localized: "Quantité")
        static let remove = String(localized: "Retirer")
        static func removeItem(_ name: String, variant: String) -> String { String(localized: "Retirer \(name), \(variant) du panier") }
        static let unavailable = String(localized: "Pièce indisponible")
        static let photo = "photo"
    }
    private enum Layout { static let image: CGFloat = 84; static let spacing: CGFloat = UFitSpace.md; static let minimum = 1 }
    var body: some View {
        VStack(alignment: .leading, spacing: Layout.spacing) {
            HStack(alignment: .top, spacing: Layout.spacing) {
                Group {
                    if let image = line.image { FashionImage(source: image) }
                    else { Color.ufitCanvas.overlay(UFitIcon(systemName: Copy.photo)) }
                }.frame(width: Layout.image, height: Layout.image).clipped()
                VStack(alignment: .leading, spacing: Layout.spacing) {
                    Text(line.name).font(UFitTypography.headline)
                    Text(line.variant).font(UFitTypography.subheadline).foregroundStyle(Color.ufitSecondaryText)
                    Text(line.amount).font(UFitTypography.subheadline.weight(.medium))
                    if !line.isAvailable { Text(Copy.unavailable).font(UFitTypography.callout) }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
                UFitQuantityControl(Copy.quantity, value: Binding(get: {line.quantity}, set: onQuantity), in: Layout.minimum...max(Layout.minimum, line.maximumQuantity))
                    .disabled(line.isBusy || !line.isAvailable)
                HStack(spacing: UFitSpace.sm) {
                    UFitButton(Copy.remove, role: .destructive, action: onRemove)
                        .ufitButtonStyle(.secondary, compact: true).disabled(line.isBusy)
                        .accessibilityLabel(Copy.removeItem(line.name, variant: line.variant))
                    if line.isBusy { UFitLoading() }
                }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}
