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
    private(set) var canReplay = false
    private(set) var journalUnavailable = false
    private(set) var recoveredOrderAvailable = false
    private(set) var requiresNewReview = false
    var message: String?
    @ObservationIgnored private let client: UFitAPIClient
    @ObservationIgnored private let session: UFitSessionStore
    @ObservationIgnored private let userID: String
    @ObservationIgnored private let cart: UFitCartStore
    @ObservationIgnored private let journal: UFitCheckoutJournal
    @ObservationIgnored private var pending: UFitCheckoutRecoveryRecord?
    private enum Confirmation {
        static let attempts = 12
        static let interval = Duration.seconds(1)
    }
    init(userID: String, session: UFitSessionStore, cart: UFitCartStore) {
        self.userID = userID; self.session = session; self.client = session.api; self.cart = cart
        self.journal = .init(userID: userID, endpoint: session.api.configuration.baseURL)
        address.fullName = session.user?.displayName ?? String()
    }
    private var isCurrentAccount: Bool { session.user?.id == userID }
    var needsOrderDetails: Bool {
        if recoveredOrderAvailable { return true }
        guard let order else { return false }
        return [.cancelling, .cancelled, .refunded].contains(order.status) || payment?.state == .closed || payment?.state == .review || payment?.state == .orderUpdated
    }
    var hasPreparedOrder: Bool { pending?.orderID != nil }
    var recoveryAmount: String? { pending.map { UFitMoney.format($0.amount, currency: $0.currency) } }
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
        guard isCurrentAccount, !isBusy, step == .address || step == .recovery else { return }
        isBusy = true; message = nil; canReplay = false
        defer { isBusy = false }
        do { pending = try journal.read(); journalUnavailable = false }
        catch { journalUnavailable = true; step = .recovery; message = UFitCheckoutRecoveryCopy.localRead; return }
        if let pending {
            address = pending.request.shippingAddress; step = .recovery
            do { try await findOrder(pending) }
            catch { if isCurrentAccount { message = recoveryMessage(error) } }
            return
        }
        step = .address
        do { try await loadDestinations() }
        catch { if isCurrentAccount { message = error.localizedDescription } }
    }
    private func loadDestinations() async throws {
        destinations = []
        guard let active = cart.cart, let brand = active.brandId else {
            message = String(localized: "Votre panier est vide. Revenez à votre sélection pour continuer."); return
        }
        guard let policy = try await client.fetchCommercePolicy(brandID: brand) else {
            message = String(localized: "La marque doit encore configurer ses conditions de livraison."); return
        }
        guard isCurrentAccount else { return }
        let locale = Locale(identifier: "fr")
        destinations = Set(policy.shippingRates.filter { $0.currency == active.currency }.map(\.country))
            .map { UFitCountry(id: $0, name: locale.localizedString(forRegionCode: $0) ?? $0) }
            .sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
        if !destinations.contains(where: { $0.id == address.country }), let first = destinations.first { address.country = first.id }
        message = destinations.isEmpty ? String(localized: "La marque ne propose pas de livraison pour cette devise.") : nil
    }
    func review() async {
        guard isCurrentAccount, !isBusy, !journalUnavailable, pending == nil else { return }
        requiresNewReview = false
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
            guard isCurrentAccount else { return }
            let result = try await client.quoteCart(country: address.country)
            guard isCurrentAccount else { return }
            guard result.items.allSatisfy({ item in cart.lines.contains { $0.id == item.id } }) else {
                message = String(localized: "Le panier a changé. Vérifiez-le avant de continuer."); return
            }
            quote = result; paymentSheet = nil; step = .review
        } catch { if isCurrentAccount { message = error.localizedDescription } }
    }
    func editAddress() { guard isCurrentAccount, !isBusy, pending == nil else { return }; step = .address; message = nil }
    func preparePayment() async -> Bool {
        guard isCurrentAccount, !isBusy, !journalUnavailable, let quote else { return false }
        isBusy = true; message = nil
        defer { isBusy = false }
        do {
            let attempt: UFitCheckoutRecoveryRecord
            if let pending { attempt = pending }
            else {
                attempt = UFitCheckoutRecoveryRecord(version: UFitCheckoutJournal.version, userID: userID,
                    endpoint: client.configuration.baseURL.absoluteString, cartID: quote.cartId,
                    request: UFitCheckoutRequest(requestId: UUID().uuidString.lowercased(), quoteFingerprint: quote.fingerprint, shippingAddress: address),
                    amount: quote.totalAmount, currency: quote.currency, outcome: .unknown)
                try persist(attempt)
            }
            return try await send(attempt, presentPayment: true)
        } catch {
            await handleSubmissionFailure(error)
            return false
        }
    }
    func replay() async {
        guard isCurrentAccount, !isBusy, !journalUnavailable, canReplay, let pending, pending.orderID == nil else { return }
        isBusy = true; message = nil; canReplay = false
        defer { isBusy = false }
        do { _ = try await send(pending, presentPayment: false) }
        catch { await handleSubmissionFailure(error) }
    }
    private func send(_ attempt: UFitCheckoutRecoveryRecord, presentPayment: Bool) async throws -> Bool {
        let result = try await client.checkout(attempt.request)
        guard isCurrentAccount else { return false }
        guard result.payment.amount == attempt.amount, result.payment.currency == attempt.currency,
              attempt.orderID == nil || attempt.orderID == result.payment.orderId else { throw UFitCheckoutRecoveryFailure.document }
        try rememberOrder(result.payment.orderId, attempt: attempt)
        payment = result.payment
        let current = try await client.fetchOrder(id: result.payment.orderId)
        guard isCurrentAccount else { return false }
        try receive(current)
        if !presentPayment { recoveredOrderAvailable = true; return false }
        if step == .paid { await cart.load(); return false }
        if let secret = result.clientSecret, current.status == .pendingPayment {
            let publicKey = try UFitPaymentSheetFactory.publicKey()
            paymentSheet = UFitPaymentSheetFactory.make(secret: secret, address: attempt.request.shippingAddress, publicKey: publicKey)
            return true
        }
        step = .confirming; return false
    }
    private func persist(_ record: UFitCheckoutRecoveryRecord) throws {
        do { try journal.record(record); pending = record }
        catch { journalUnavailable = true; throw UFitCheckoutRecoveryFailure.localWrite }
    }
    private func resolveJournal() throws {
        do { try journal.resolve() }
        catch { journalUnavailable = true; throw UFitCheckoutRecoveryFailure.localWrite }
    }
    private func rememberOrder(_ id: String, attempt: UFitCheckoutRecoveryRecord) throws {
        guard attempt.orderID == nil || attempt.orderID == id else { throw UFitCheckoutRecoveryFailure.document }
        var record = attempt; record.outcome = .order(id: id)
        try persist(record)
    }
    private func findOrder(_ attempt: UFitCheckoutRecoveryRecord) async throws {
        let outcome = try await client.checkoutOutcome(requestID: attempt.request.requestId, knownOrderID: attempt.orderID)
        guard isCurrentAccount else { return }
        guard let id = outcome.orderId else { canReplay = true; return }
        try rememberOrder(id, attempt: attempt)
        let result = try await client.fetchOrder(id: id)
        guard isCurrentAccount else { return }
        try receive(result); recoveredOrderAvailable = true
    }
    private func handleSubmissionFailure(_ error: Error) async {
        guard isCurrentAccount else { return }
        paymentSheet = nil; canReplay = false
        if journalUnavailable { step = .recovery }
        if let attempt = pending {
            step = .recovery
            if case UFitAPIError.requestFailed(_, _, let code) = error,
               code == UFitCheckoutRecoveryHTTP.quoteChanged, attempt.orderID == nil {
                do {
                    let outcome = try await client.checkoutOutcome(requestID: attempt.request.requestId, knownOrderID: nil)
                    guard isCurrentAccount else { return }
                    if outcome.orderId == nil {
                        // No sheet was presented for this request; a rejected quote needs a new explicit review.
                        try resolveJournal(); pending = nil; quote = nil; step = .address
                        requiresNewReview = true
                        await cart.load()
                        guard isCurrentAccount else { return }
                        try await loadDestinations()
                        if message == nil { message = UFitCheckoutRecoveryCopy.changed }
                        return
                    }
                } catch { message = recoveryMessage(error); return }
            }
        }
        message = recoveryMessage(error)
    }
    func paymentFinished(_ result: PaymentSheetResult) async {
        guard isCurrentAccount else { paymentSheet = nil; return }
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
        guard isCurrentAccount, !isBusy, let orderID = pending?.orderID else { return }
        isBusy = true; message = nil; step = .confirming; payment = nil
        defer { isBusy = false }
        do {
            for attempt in .zero..<(polling ? Confirmation.attempts : 1) {
                try Task.checkCancellation()
                let updated = try await client.fetchOrder(id: orderID)
                guard isCurrentAccount else { return }
                try receive(updated)
                if [.paid, .preparing, .shipped, .delivered].contains(updated.status) { await cart.load(); return }
                if needsOrderDetails { await cart.load(); return }
                if updated.status != .pendingPayment { throw UFitCheckoutRecoveryFailure.document }
                let status = try await client.fetchOrderPayment(updated)
                guard isCurrentAccount else { return }
                payment = status
                if status.state.canResume {
                    if quote != nil { step = .review } else { recoveredOrderAvailable = true }
                    return
                }
                if status.orderStatus != updated.status { continue }
                if polling && attempt < Confirmation.attempts - 1 { try await Task.sleep(for: Confirmation.interval) }
            }
        } catch is CancellationError { return }
        catch { if isCurrentAccount { payment = nil; message = recoveryMessage(error) } }
    }
    private func receive(_ updated: UFitOrderDTO) throws {
        guard let pending, updated.id == pending.orderID, updated.totalAmount == pending.amount,
              updated.currency == pending.currency else { throw UFitCheckoutRecoveryFailure.document }
        order = updated
        if [.paid, .preparing, .shipped, .delivered, .cancelled, .refunded].contains(updated.status) {
            try resolveJournal()
        }
        if [.paid, .preparing, .shipped, .delivered].contains(updated.status) { step = .paid; payment = nil }
    }
    private func recoveryMessage(_ error: Error) -> String {
        if error is DecodingError { return UFitCheckoutRecoveryCopy.invalid }
        if case UFitAPIError.requestFailed(_, _, let code) = error, code == UFitCheckoutRecoveryHTTP.invalid { return UFitCheckoutRecoveryCopy.invalid }
        if case UFitAPIError.requestFailed(_, _, let code) = error, code == UFitCheckoutRecoveryHTTP.commissionUnavailable { return UFitCheckoutRecoveryCopy.commissionUnavailable }
        return UFitCustomerPaymentCopy.message(error)
    }
}
