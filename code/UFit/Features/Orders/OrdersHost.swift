import SwiftUI

struct UFitOrdersHost: View {
    let store: UFitOrdersStore
    let onBack: () -> Void
    let onSelect: (String) -> Void
    var body: some View {
        UFitOrdersContent(orders: store.summaries, isLoading: store.isLoading, hasMore: store.nextCursor != nil, message: store.message,
            onBack: onBack, onSelect: onSelect, onRefresh: {Task {await store.load()}}, onMore: {Task {await store.load(reset: false)}})
            .task {await store.load()}
    }
}
struct UFitOrderDetailHost: View {
    let store: UFitOrderDetailStore
    let onBack: () -> Void
    var body: some View {
        UFitOrderDetailContent(order: store.presentation, isBusy: store.isBusy, message: store.message, onBack: onBack,
            onRefresh: {Task {await store.load()}}, onPay: {Task {await store.resumePayment()}}, onCancel: {Task {await store.cancel()}})
            .task {await store.load()}
            .task(id: store.order?.status) { await store.followCancellation() }
            .background {
                if let sheet = store.paymentSheet {
                    UFitStripePaymentPresentation(sheet: sheet) {result in Task {await store.paymentFinished(result)}}.id(ObjectIdentifier(sheet))
                }
            }
    }
}
