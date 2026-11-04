import Foundation
import Observation
import StripePaymentSheet

@MainActor @Observable
final class UFitCheckoutStore {
    var address = UFitShippingAddress()
    private(set) var step = UFitCheckoutStep.address
    private(set) var destinations = [UFitCountry]()
    private(set) var isBusy = false
    private(set) var quote: UFitCartQuoteDTO?
    private(set) var order: UFitOrderDTO?
    private(set) var paymentSheet: PaymentSheet?
    private(set) var payment: UFitCustomerPaymentStatusDTO?
    var message: String?
    @ObservationIgnored private let client: UFitAPIClient
    @ObservationIgnored private let cart: UFitCartStore
    @ObservationIgnored private var requestID: String?
    @ObservationIgnored private var orderID: String?
    private enum Confirmation {
        static let attempts = 12
        static let interval = Duration.seconds(1)
    }
    init(client: UFitAPIClient, cart: UFitCartStore, name: String?) {
        self.client = client; self.cart = cart; address.fullName = name ?? String()
    }
    var needsOrderDetails: Bool {
        guard let order else { return false }
        return [.cancelling, .cancelled, .refunded].contains(order.status) || payment?.state == .closed || payment?.state == .review || payment?.state == .orderUpdated
    }
    var hasPreparedOrder: Bool { orderID != nil }
    var lines: [UFitCartPresentationLine] {
        guard let quote else { return cart.lines }
        return quote.items.compactMap { item in
            guard let line = cart.lines.first(where: { $0.id == item.id }) else { return nil }
            return UFitCartPresentationLine(id: item.id, name: line.name, variant: line.variant, image: line.image,
                quantity: item.quantity, maximumQuantity: line.maximumQuantity,
                amount: UFitMoney.format(item.unitPrice * item.quantity, currency: quote.currency), isBusy: false, isAvailable: true)
        }
    }
    var summary: UFitCheckoutSummary? {
        quote.map { value in
            UFitCheckoutSummary(subtotal: UFitMoney.format(value.subtotalAmount, currency: value.currency),
                shipping: UFitMoney.format(value.shippingAmount, currency: value.currency),
                taxes: UFitMoney.format(value.taxAmount, currency: value.currency),
                total: UFitMoney.format(value.totalAmount, currency: value.currency),
                returnPolicy: value.returnPolicy, refundPolicy: value.refundPolicyCode, taxNotice: value.taxNotice, customsNotice: value.customsNotice)
        }
    }
    func load() async {
        guard !isBusy else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            guard let active = cart.cart, let brand = active.brandId,
                  let policy = try await client.fetchCommercePolicy(brandID: brand) else {
                message = String(localized: "La marque doit encore configurer ses conditions de livraison."); return
            }
            let locale = Locale(identifier: "fr")
            destinations = Set(policy.shippingRates.filter { $0.currency == active.currency }.map(\.country))
                .map { UFitCountry(id: $0, name: locale.localizedString(forRegionCode: $0) ?? $0) }
                .sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
            if !destinations.contains(where: { $0.id == address.country }), let first = destinations.first { address.country = first.id }
            message = destinations.isEmpty ? String(localized: "La marque ne propose pas de livraison pour cette devise.") : nil
        } catch { message = error.localizedDescription }
    }
    func review() async {
        guard !isBusy else { return }
        address.fullName = address.fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        address.line1 = address.line1.trimmingCharacters(in: .whitespacesAndNewlines)
        address.postalCode = address.postalCode.trimmingCharacters(in: .whitespacesAndNewlines)
        address.city = address.city.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !address.fullName.isEmpty, !address.line1.isEmpty, !address.postalCode.isEmpty, !address.city.isEmpty else {
            message = String(localized: "Complétez votre nom et votre adresse de livraison."); return
        }
        isBusy = true; message = nil
        defer { isBusy = false }
        do {
            await cart.load()
            let result = try await client.quoteCart(country: address.country)
            guard result.items.allSatisfy({ item in cart.lines.contains { $0.id == item.id } }) else {
                message = String(localized: "Le panier a changé. Vérifiez-le avant de continuer."); return
            }
            quote = result; requestID = nil; orderID = nil; paymentSheet = nil; step = .review
        } catch { message = error.localizedDescription }
    }
    func editAddress() { guard !isBusy, !hasPreparedOrder else { return }; step = .address; message = nil }
    func preparePayment() async -> Bool {
        guard !isBusy, let quote else { return false }
        isBusy = true; message = nil
        defer { isBusy = false }
        requestID = requestID ?? UUID().uuidString
        do {
            let intent = try await client.checkout(UFitCheckoutRequest(requestId: requestID!, quoteFingerprint: quote.fingerprint, shippingAddress: address))
            guard intent.payment.amount == quote.totalAmount, intent.payment.currency == quote.currency,
                  orderID == nil || orderID == intent.payment.orderId else { throw UFitCustomerPaymentFailure.document }
            orderID = intent.payment.orderId; payment = intent.payment
            let current = try await client.fetchOrder(id: intent.payment.orderId)
            try receive(current)
            if step == .paid { await cart.load(); return false }
            if let secret = intent.clientSecret, current.status == .pendingPayment {
                let publicKey = try UFitPaymentSheetFactory.publicKey()
                paymentSheet = UFitPaymentSheetFactory.make(secret: secret, address: address, publicKey: publicKey)
                return true
            }
            step = .confirming; return false
        } catch {
            if let failure = error as? UFitAPIError, case .requestFailed(_, _, let code) = failure, code == "checkout_quote_changed" {
                step = .address; self.quote = nil; requestID = nil
            }
            message = UFitCustomerPaymentCopy.message(error)
            return false
        }
    }
    func paymentFinished(_ result: PaymentSheetResult) async {
        paymentSheet = nil
        switch result {
        case .completed: step = .confirming; await refreshConfirmation(polling: true)
        case .canceled:
            await refreshConfirmation()
            if payment?.state.canResume == true { message = UFitCustomerPaymentCopy.interrupted }
        case .failed:
            await refreshConfirmation()
            if payment?.state.canResume == true { message = UFitCustomerPaymentCopy.failed }
        }
    }
    func refreshConfirmation(polling: Bool = false) async {
        guard !isBusy, let orderID else { return }
        isBusy = true; message = nil; step = .confirming; payment = nil
        defer { isBusy = false }
        do {
            for attempt in .zero..<(polling ? Confirmation.attempts : 1) {
                try Task.checkCancellation()
                let updated = try await client.fetchOrder(id: orderID)
                try receive(updated)
                if [.paid, .preparing, .shipped, .delivered].contains(updated.status) {
                    step = .paid; await cart.load(); return
                }
                if needsOrderDetails { await cart.load(); return }
                if updated.status != .pendingPayment {
                    message = String(localized: "Cette commande n’est plus en attente de paiement."); return
                }
                let status = try await client.fetchOrderPayment(updated)
                payment = status
                if status.state.canResume { step = .review; return }
                if status.orderStatus != updated.status { continue }
                if polling && attempt < Confirmation.attempts - 1 { try await Task.sleep(for: Confirmation.interval) }
            }
        } catch is CancellationError { return }
        catch { payment = nil; message = UFitCustomerPaymentCopy.message(error) }
    }
    private func receive(_ updated: UFitOrderDTO) throws {
        guard updated.id == orderID, let quote, updated.totalAmount == quote.totalAmount, updated.currency == quote.currency else { throw UFitCustomerPaymentFailure.document }
        order = updated
        if [.paid, .preparing, .shipped, .delivered].contains(updated.status) { step = .paid; payment = nil }
    }
}
