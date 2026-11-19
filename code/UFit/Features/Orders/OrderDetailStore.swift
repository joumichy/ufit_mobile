import Foundation
import Observation
import StripePaymentSheet

@MainActor @Observable
final class UFitOrderDetailStore {
    private(set) var order: UFitOrderDTO?
    private(set) var isBusy = false
    private(set) var paymentSheet: PaymentSheet?
    private(set) var payment: UFitCustomerPaymentStatusDTO?
    private(set) var paymentMessage: String?
    var message: String?
    @ObservationIgnored private let id: String
    @ObservationIgnored private let client: UFitAPIClient
    @ObservationIgnored let session: UFitSessionStore
    @ObservationIgnored private let orders: UFitOrdersStore
    private enum Confirmation { static let attempts = 12; static let interval = Duration.seconds(1) }
    init(id: String, client: UFitAPIClient, session: UFitSessionStore, orders: UFitOrdersStore) {
        self.id = id; self.client = client; self.session = session; self.orders = orders
    }
    var presentation: UFitOrderDetailPresentation? {
        guard let order else { return nil }
        var result = UFitOrderPresentationAdapter.detail(order)
        result.needsPaymentStatus = order.status == .pendingPayment
        result.canResumePayment = order.status == .pendingPayment && payment?.state.canResume == true && paymentMessage == nil
        return result
    }
    private func receive(_ order: UFitOrderDTO) {
        self.order = order; orders.receive(order)
        guard let userID = session.user?.id else { return }
        do { try UFitCheckoutJournal(userID: userID, endpoint: client.configuration.baseURL).resolve(confirmedOrder: order) }
        catch { message = error.localizedDescription }
    }
    func load() async {
        guard !isBusy, let userID = session.user?.id else { return }
        isBusy = true; message = nil; payment = nil; paymentMessage = nil
        defer { isBusy = false }
        do {
            let result = try await client.fetchOrder(id: id)
            guard session.user?.id == userID else { return }; receive(result)
            await readPayment(for: result, userID: userID)
        }
        catch { if session.user?.id == userID { message = error.localizedDescription } }
    }
    private func readPayment(for order: UFitOrderDTO, userID: String) async {
        guard order.status == .pendingPayment else { payment = nil; paymentMessage = nil; return }
        do {
            let result = try await client.fetchOrderPayment(order)
            guard session.user?.id == userID else { return }
            payment = result; paymentMessage = nil
            if result.orderStatus != order.status {
                let latest = try await client.fetchOrder(id: id)
                guard session.user?.id == userID else { return }; receive(latest)
                if latest.status != .pendingPayment { payment = nil }
            }
        } catch {
            guard session.user?.id == userID else { return }
            payment = nil; paymentMessage = UFitCustomerPaymentCopy.message(error)
        }
    }
    func cancel() async {
        guard !isBusy, order?.actions.cancel == true, let userID = session.user?.id else { return }
        isBusy = true; message = nil
        defer { isBusy = false }
        do { let result = try await client.cancelOrder(id: id); if session.user?.id == userID { receive(result) } }
        catch {
            guard session.user?.id == userID else { return }
            let failure = error.localizedDescription
            if let current = try? await client.fetchOrder(id: id), session.user?.id == userID {
                receive(current)
                if current.cancellation != nil {
                    message = String(localized: "L’annulation a été enregistrée. Le statut affiché a été actualisé.")
                    return
                }
            }
            if session.user?.id == userID { message = failure }
        }
    }
    func followCancellation() async {
        guard order?.cancellation?.status == .requested, let userID = session.user?.id else { return }
        do {
            for _ in .zero..<Confirmation.attempts {
                try await Task.sleep(for: Confirmation.interval)
                guard session.user?.id == userID, order?.cancellation?.status == .requested else { return }
                let current = try await client.fetchOrder(id: id)
                guard session.user?.id == userID, order?.cancellation?.status == .requested else { return }
                receive(current)
                if current.cancellation?.status != .requested { return }
            }
        } catch is CancellationError { return }
        catch { if session.user?.id == userID { message = error.localizedDescription } }
    }
    func resumePayment() async {
        guard !isBusy, let order, presentation?.canResumePayment == true, let userID = session.user?.id else { return }
        isBusy = true; message = nil
        defer { isBusy = false }
        do {
            let result = try await client.resumeOrderPayment(order)
            guard session.user?.id == userID else { return }
            payment = result.payment; paymentMessage = nil
            if let secret = result.clientSecret {
                let key = try UFitPaymentSheetFactory.publicKey()
                paymentSheet = UFitPaymentSheetFactory.make(secret: secret, address: order.shippingAddress, publicKey: key)
            } else if result.payment.orderStatus != order.status {
                let latest = try await client.fetchOrder(id: id)
                guard session.user?.id == userID else { return }; receive(latest)
                if latest.status != .pendingPayment { payment = nil }
            }
        } catch { if session.user?.id == userID { payment = nil; paymentMessage = UFitCustomerPaymentCopy.message(error) } }
    }
    func paymentFinished(_ result: PaymentSheetResult) async {
        paymentSheet = nil
        switch result {
        case .completed: await confirmPayment()
        case .canceled:
            await load()
        case .failed:
            await load()
            if payment?.state.canResume == true { message = UFitCustomerPaymentCopy.failed }
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
                if result.status != .pendingPayment { payment = nil; return }
                await readPayment(for: result, userID: userID)
                if attempt < Confirmation.attempts - 1 { try await Task.sleep(for: Confirmation.interval) }
            }
        } catch is CancellationError { return }
        catch { if session.user?.id == userID { message = error.localizedDescription } }
    }
}
