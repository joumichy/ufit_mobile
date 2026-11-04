import Foundation

enum UFitCustomerPaymentHTTP {
    static let get = "GET", post = "POST", orders = "orders/", status = "/payment-status", session = "/payment"
    static let checkout = "orders/checkout"
    static let maximum = 2_147_483_647, intentPattern = "^pi_[A-Za-z0-9]+$", secretSeparator = "_secret_"
    static let failures = ["customer_payment_unavailable", "customer_payment_invalid"]
}
extension UFitAPIClient {
    func fetchOrderPayment(_ order: UFitOrderDTO) async throws -> UFitCustomerPaymentStatusDTO {
        let result: UFitCustomerPaymentStatusDTO = try await send(UFitCustomerPaymentHTTP.get,
            path: UFitCustomerPaymentHTTP.orders + order.id + UFitCustomerPaymentHTTP.status,
            requiresAuth: true, cachePolicy: .reloadIgnoringLocalCacheData)
        try result.validate(order: order); return result
    }
    func resumeOrderPayment(_ order: UFitOrderDTO) async throws -> UFitCustomerPaymentSessionDTO {
        let result: UFitCustomerPaymentSessionDTO = try await send(UFitCustomerPaymentHTTP.post,
            path: UFitCustomerPaymentHTTP.orders + order.id + UFitCustomerPaymentHTTP.session, requiresAuth: true)
        try result.validate(order: order); return result
    }
}
