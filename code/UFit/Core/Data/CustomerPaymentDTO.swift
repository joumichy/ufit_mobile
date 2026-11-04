import Foundation

enum UFitCustomerPaymentFailure: LocalizedError {
    case document
    var errorDescription: String? { UFitCustomerPaymentCopy.invalid }
}
struct UFitCustomerPaymentStatusDTO: Decodable {
    let orderId: String; let orderStatus: UFitOrderLifecycle
    let amount: Int; let currency: String; let observedAt: UFitTimestamp
    let state: UFitCustomerPaymentState
    @UFitRequiredNullable var paymentIntentId: String?
    @UFitRequiredNullable var liveMode: Bool?
    func validate(order: UFitOrderDTO? = nil) throws {
        guard UUID(uuidString: orderId) != nil, amount > .zero, amount <= UFitCustomerPaymentHTTP.maximum,
              currency.range(of: UFitCurrency.codePattern, options: .regularExpression) != nil,
              (orderStatus != .pendingPayment) == (state == .orderUpdated),
              paymentIntentId != nil || liveMode == nil else { throw UFitCustomerPaymentFailure.document }
        if let paymentIntentId {
            guard paymentIntentId.range(of: UFitCustomerPaymentHTTP.intentPattern, options: .regularExpression) != nil else { throw UFitCustomerPaymentFailure.document }
        }
        if state == .notStarted {
            guard paymentIntentId == nil, liveMode == nil else { throw UFitCustomerPaymentFailure.document }
        } else if state != .orderUpdated {
            guard paymentIntentId != nil, liveMode != nil else { throw UFitCustomerPaymentFailure.document }
        }
        if let order {
            guard orderId == order.id, amount == order.totalAmount, currency == order.currency else { throw UFitCustomerPaymentFailure.document }
        }
    }
}
struct UFitCustomerPaymentSessionDTO: Decodable {
    let payment: UFitCustomerPaymentStatusDTO
    @UFitRequiredNullable var clientSecret: String?
    func validate(order: UFitOrderDTO? = nil) throws {
        try payment.validate(order: order)
        if payment.state.canResume && payment.state != .notStarted {
            guard let clientSecret, let id = payment.paymentIntentId,
                  clientSecret.hasPrefix(id + UFitCustomerPaymentHTTP.secretSeparator),
                  clientSecret.count > (id + UFitCustomerPaymentHTTP.secretSeparator).count else { throw UFitCustomerPaymentFailure.document }
        } else if clientSecret != nil { throw UFitCustomerPaymentFailure.document }
    }
}
