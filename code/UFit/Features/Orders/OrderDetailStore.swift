import Foundation
import Observation
import StripePaymentSheet

@MainActor @Observable
final class UFitOrderDetailStore {
    private(set) var order: UFitOrderDTO?
    private(set) var isBusy = false
    private(set) var paymentSheet: PaymentSheet?
    var message: String?
    @ObservationIgnored private let id: String
    @ObservationIgnored private let client: UFitAPIClient
    @ObservationIgnored private let session: UFitSessionStore
    @ObservationIgnored private let orders: UFitOrdersStore
    private enum Confirmation { static let attempts = 12; static let interval = Duration.seconds(1) }
    init(id: String, client: UFitAPIClient, session: UFitSessionStore, orders: UFitOrdersStore) {
        self.id = id; self.client = client; self.session = session; self.orders = orders
    }
    var presentation: UFitOrderDetailPresentation? { order.map(UFitOrderPresentationAdapter.detail) }
    private func receive(_ order: UFitOrderDTO) { self.order = order; orders.receive(order) }
    func load() async {
        guard !isBusy, let userID = session.user?.id else { return }
        isBusy = true; message = nil
        defer { isBusy = false }
        do { let result = try await client.fetchOrder(id: id); if session.user?.id == userID { receive(result) } }
        catch { if session.user?.id == userID { message = error.localizedDescription } }
    }
    func cancel() async {
        guard !isBusy, order?.actions.cancel == true, let userID = session.user?.id else { return }
        isBusy = true; message = nil
        defer { isBusy = false }
        do { let result = try await client.cancelOrder(id: id); if session.user?.id == userID { receive(result) } }
        catch {
            guard session.user?.id == userID else { return }
            let failure = error.localizedDescription
            if let current = try? await client.fetchOrder(id: id), session.user?.id == userID { receive(current) }
            if session.user?.id == userID { message = failure }
        }
    }
    func resumePayment() async {
        guard !isBusy, let order, order.actions.resumePayment, let userID = session.user?.id else { return }
        isBusy = true; message = nil
        defer { isBusy = false }
        do {
            let key = try UFitPaymentSheetFactory.publicKey()
            let result = try await client.resumeOrderPayment(id: id)
            guard session.user?.id == userID else { return }
            paymentSheet = UFitPaymentSheetFactory.make(secret: result.clientSecret, address: order.shippingAddress, publicKey: key)
        } catch { if session.user?.id == userID { message = error.localizedDescription } }
    }
    func paymentFinished(_ result: PaymentSheetResult) async {
        paymentSheet = nil
        switch result {
        case .completed: await confirmPayment()
        case .canceled: message = String(localized: "Le paiement a été interrompu. Vous pouvez le reprendre.")
        case .failed: message = String(localized: "Le paiement n’a pas abouti. Vous pouvez réessayer.")
        }
    }
    private func confirmPayment() async {
        guard !isBusy, let userID = session.user?.id else { return }
        isBusy = true; message = nil
        defer { isBusy = false }
        do {
            for attempt in .zero..<Confirmation.attempts {
                try Task.checkCancellation()
                let result = try await client.fetchOrder(id: id)
                guard session.user?.id == userID else { return }
                receive(result)
                if result.status != .pendingPayment { return }
                if attempt < Confirmation.attempts - 1 { try await Task.sleep(for: Confirmation.interval) }
            }
            message = String(localized: "Le paiement est en cours de confirmation. Actualisez le statut de la commande.")
        } catch is CancellationError { return }
        catch { if session.user?.id == userID { message = error.localizedDescription } }
    }
}
