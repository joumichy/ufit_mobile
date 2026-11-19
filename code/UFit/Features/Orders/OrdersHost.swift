import SwiftUI

struct UFitOrdersHost: View {
    let store: UFitOrdersStore
    let onBack: () -> Void
    let onSelect: (String) -> Void
    var body: some View {
        UFitOrdersContent(orders: store.summaries, isLoading: store.isLoading, hasLoaded: store.hasLoaded, hasMore: store.nextCursor != nil, message: store.message,
            onBack: onBack, onSelect: onSelect, onRefresh: {await store.load()}, onMore: {Task {await store.load(reset: false)}})
            .task {await store.load()}
    }
}
struct UFitOrderDetailHost: View {
    let store: UFitOrderDetailStore
    let onBack: () -> Void
    let onReturns: () -> Void
    @State private var refundOrganization: UFitRefundOrganizationStore?
    @Environment(\.scenePhase) private var scenePhase
    var body: some View {
        UFitOrderDetailContent(order: store.presentation, isBusy: store.isBusy, message: store.message, onBack: onBack,
            onRefresh: {Task {await store.load()}}, onPay: {Task {await store.resumePayment()}}, onCancel: {Task {await store.cancel()}}, onReturns: onReturns,
            payment: store.payment, paymentMessage: store.paymentMessage,
            onRefundOrganization: store.order?.cancellation?.refundOrganizationReference == nil ? nil : showRefundOrganization)
            .task {await store.load()}
            .onChange(of: scenePhase) { _, phase in if phase == .active {Task {await store.load()}} }
            .task(id: store.order?.cancellation?.status) { await store.followCancellation() }
            .background {
                if let sheet = store.paymentSheet {
                    UFitStripePaymentPresentation(sheet: sheet) {result in Task {await store.paymentFinished(result)}}.id(ObjectIdentifier(sheet))
                }
            }
            .ufitSheet(item: $refundOrganization, onDismiss: {Task {await store.load()}}) {current in
                UFitRefundOrganizationHost(store: current, onClose: {refundOrganization = nil})
            }
    }
    private func showRefundOrganization() {
        guard let reference = store.order?.cancellation?.refundOrganizationReference else {return}
        refundOrganization = .init(scope: .customer, reference: reference, session: store.session)
    }
}
