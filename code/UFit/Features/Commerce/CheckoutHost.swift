import SwiftUI
import StripePaymentSheet

struct UFitCheckoutHost: View {
    @Bindable var store: UFitCheckoutStore
    let onBack: () -> Void
    let onFinish: () -> Void
    var body: some View {
        UFitCheckoutContent(address: $store.address, step: store.step, destinations: store.destinations,
            lines: store.lines, summary: store.summary, isBusy: store.isBusy, message: store.message,
            orderNumber: store.order?.orderNumber, onBack: {
                if store.step == .review { store.editAddress() } else { onBack() }
            }, onReview: { Task { await store.review() } },
            onPay: { Task { _ = await store.preparePayment() } },
            onRefresh: { Task { await store.refreshConfirmation() } }, onFinish: onFinish)
            .task { await store.load() }
            .background {
                if let sheet = store.paymentSheet {
                    UFitStripePaymentPresentation(sheet: sheet) { result in
                        Task { await store.paymentFinished(result) }
                    }.id(ObjectIdentifier(sheet))
                }
            }
    }
}
