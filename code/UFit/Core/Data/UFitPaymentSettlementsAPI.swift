import Foundation

enum UFitPaymentSettlementHTTP {
    static let get = "GET", post = "POST", root = "admin/payments/", document = "/settlement", synchronize = "/settlement-sync"
    static let missing = 404, unsupported = "payment_settlement_unsupported"
    static let chargePattern = "^ch_[A-Za-z0-9]+$", transactionPattern = "^txn_[A-Za-z0-9]+$"
    static let pollInterval = Duration.seconds(2)
    static func path(_ id: String, suffix: String) throws -> String {
        guard UUID(uuidString: id) != nil, id == id.lowercased() else { throw UFitPaymentSettlementFailure.document }
        return root + id + suffix
    }
}
enum UFitPaymentSettlementFailure: LocalizedError {
    case document
    var errorDescription: String? { UFitPaymentSettlementCopy.invalid }
}
struct UFitPaymentSettlementDocument: Decodable {
    enum State: String, Decodable { case notRequested = "not_requested", queued, processing, recorded, needsReview = "needs_review" }
    enum Failure: String, Decodable {
        case missing = "stripe_capture_missing", mismatch = "stripe_capture_mismatch", invalid = "stripe_capture_invalid"
        case balancePending = "stripe_balance_pending", unavailable = "stripe_temporarily_unavailable"
        case linked = "stripe_capture_already_linked", changed = "payment_capture_changed"
    }
    struct Payment: Decodable {
        let id: String; let orderId: String; let orderNumber: String
        let status: UFitAdminOrderPayment.Status; let amount: Int; let currency: String
        let providerPaymentIntentId: String; let createdAt: UFitTimestamp
    }
    struct Receipt: Decodable {
        let chargeId: String; let balanceTransactionId: String
        let chargeAmount: Int; let chargeCurrency: String; let settlementAmount: Int; let settlementCurrency: String
        let feeAmount: Int; let netAmount: Int; let capturedAt: UFitTimestamp; let availableAt: UFitTimestamp
        let liveMode: Bool; let recordedAt: UFitTimestamp
        func validate(payment: Payment) throws {
            guard chargeId.range(of: UFitPaymentSettlementHTTP.chargePattern, options: .regularExpression) != nil,
                  balanceTransactionId.range(of: UFitPaymentSettlementHTTP.transactionPattern, options: .regularExpression) != nil,
                  chargeAmount == payment.amount, chargeCurrency == payment.currency,
                  settlementAmount > .zero, [settlementAmount, feeAmount].allSatisfy(UFitReturnContract.money),
                  UFitReturnContract.currency(settlementCurrency),
                  (-UFitDecimalInput.maximumInteger...UFitDecimalInput.maximumInteger).contains(netAmount),
                  settlementAmount - feeAmount == netAmount else { throw UFitPaymentSettlementFailure.document }
        }
    }
    let payment: Payment; let state: State; let asOf: UFitTimestamp
    @UFitRequiredNullable var receipt: Receipt?
    @UFitRequiredNullable var failureCode: Failure?
    @UFitRequiredNullable var nextAttemptAt: UFitTimestamp?
    var waitsForReceipt: Bool { state == .queued || state == .processing }
    func validate(paymentID: String, orderID: String) throws {
        guard payment.id == paymentID, payment.orderId == orderID,
              [payment.id, payment.orderId].allSatisfy({ UUID(uuidString: $0) != nil }),
              UFitReturnContract.nonempty(payment.orderNumber), UFitReturnContract.nonempty(payment.providerPaymentIntentId),
              payment.amount > .zero, UFitReturnContract.money(payment.amount), UFitReturnContract.currency(payment.currency),
              (state == .recorded) == (receipt != nil), (state == .queued) == (nextAttemptAt != nil),
              state != .needsReview || failureCode != nil,
              failureCode == nil || state == .queued || state == .needsReview else { throw UFitPaymentSettlementFailure.document }
        try receipt?.validate(payment: payment)
    }
}
extension UFitAPIClient {
    func fetchPaymentSettlement(paymentID: String, orderID: String) async throws -> UFitPaymentSettlementDocument {
        let document: UFitPaymentSettlementDocument = try await send(UFitPaymentSettlementHTTP.get,
            path: UFitPaymentSettlementHTTP.path(paymentID, suffix: UFitPaymentSettlementHTTP.document), requiresAuth: true)
        try document.validate(paymentID: paymentID, orderID: orderID); return document
    }
    func synchronizePaymentSettlement(paymentID: String, orderID: String) async throws -> UFitPaymentSettlementDocument {
        struct Request: Encodable {}
        let document: UFitPaymentSettlementDocument = try await send(UFitPaymentSettlementHTTP.post,
            path: UFitPaymentSettlementHTTP.path(paymentID, suffix: UFitPaymentSettlementHTTP.synchronize), body: Request(), requiresAuth: true, publicOutfitsChange: false)
        try document.validate(paymentID: paymentID, orderID: orderID); return document
    }
}
