import SwiftUI

struct UFitPublicProductContent: View {
    let store: UFitPublicProductStore
    let session: UFitSessionStore
    let cart: UFitCartStore
    let onBack: () -> Void
    let onBrand: (String) -> Void
    let onCart: () -> Void
    let onSignIn: () -> Void
    var body: some View {
        VStack(spacing: .zero) {
            DetailHeader(title: UFitPublicProductCopy.title, onBack: onBack) {
                UFitButton(UFitPublicProductCopy.cart, action: onCart).ufitButtonStyle(.text)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: UFitSpace.xl) {
                    if store.isUnavailable && !store.isLoading {
                        UFitEmptyState(title: UFitPublicProductCopy.unavailable, symbol: UFitPublicProductCopy.icon,
                            actionTitle: UFitPublicProductCopy.refresh, action: refresh).padding(UFitSpace.page)
                    } else if let product = store.product, let piece = store.piece {
                        UFitOutfitGalleryContent(photos: store.photos, contentMode: .fit, surface: .canvas, photoAccessibilityLabel: UFitPublicProductCopy.photos)
                        VStack(alignment: .leading, spacing: UFitSpace.lg) {
                            if let brand = store.brand {
                                UFitButton { onBrand(brand.id) } label: {
                                    HStack { Text(brand.brandName); UFitIcon(systemName: UFitPublicProductCopy.brandChevron) }
                                }.ufitButtonStyle(.text).font(UFitTypography.subheadline).frame(minHeight: UFitControlSize.touch, alignment: .leading)
                            }
                            UFitEditorialHeading(title: product.name)
                            Text(piece.price).font(UFitTypography.title3.weight(.semibold))
                            if store.isLoading { UFitLoading(UFitPublicProductCopy.loading) }
                            if let message = store.loadError {
                                UFitNotice(message: message, kind: .error)
                                UFitActionButton(title: UFitFeedbackCopy.retry, kind: .secondary, action: refresh)
                            }
                            if let error = store.addError { UFitNotice(message: error, kind: .error) }
                            if store.additionUnconfirmed || store.hasCartConflict {
                                UFitActionButton(title: UFitPublicProductCopy.cart, action: onCart)
                                if let option = piece.variants.first(where: { $0.id == piece.selectedVariantID }) {
                                    Text(UFitPublicProductCopy.selection(option.label, quantity: piece.quantity)).font(UFitTypography.callout).foregroundStyle(Color.ufitSecondaryText)
                                }
                            } else if piece.variants.isEmpty { UFitEmptyState(title: UFitPublicProductCopy.noVariants, symbol: UFitPublicProductCopy.icon) }
                            else { UFitPurchaseOptions(piece: piece, disabled: store.isLoading,
                                onSelect: store.choose, onQuantity: store.setQuantity, onAdd: add) }
                            Text(product.description).font(UFitTypography.body).fixedSize(horizontal: false, vertical: true)
                        }.padding(.horizontal, UFitSpace.page)
                    } else if store.isLoading || store.loadError == nil {
                        UFitLoading(UFitPublicProductCopy.loading).frame(maxWidth: .infinity).padding(UFitSpace.page)
                    } else {
                        UFitEmptyState(title: UFitPublicProductCopy.failed, message: store.loadError, symbol: UFitPublicProductCopy.errorIcon,
                            actionTitle: UFitFeedbackCopy.retry, action: refresh).padding(UFitSpace.page)
                    }
                }.padding(.bottom, UFitSpace.xl)
            }.ufitRefreshable(isEnabled: !store.isLoading && !store.isAdding, title: UFitPublicProductCopy.refresh) { await store.load() }
        }.foregroundStyle(Color.ufitInk).background(Color.ufitCanvas).task {
            if !store.hasLoaded { await store.load() }
            store.reconcileCart(cart)
        }.onChange(of: cart.isLoading) { _, loading in if !loading { store.reconcileCart(cart) } }
    }
    private func refresh() { Task { await store.load() } }
    private func add() {
        guard session.user != nil else { onSignIn(); return }
        Task { if let updated = await store.add() { await cart.receive(updated) } }
    }
}
