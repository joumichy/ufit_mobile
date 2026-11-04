import Foundation

enum UFitCheckoutRecoveryHTTP {
    static let route = "orders/checkout-requests/"
    static let invalid = "checkout_recovery_invalid"
    static let quoteChanged = "checkout_quote_changed"
    static let commissionUnavailable = "commission_rule_unconfigured"
    static let fingerprintPattern = "^[a-f0-9]{64}$"
}

struct UFitCheckoutOutcomeDTO: Decodable {
    let requestId: String
    @UFitRequiredNullable var orderId: String?
    func validate(requestID: String, knownOrderID: String?) throws {
        guard UUID(uuidString: requestId) != nil, requestId == requestID,
              knownOrderID == nil || knownOrderID == orderId else { throw UFitCheckoutRecoveryFailure.document }
        if let orderId, UUID(uuidString: orderId) == nil { throw UFitCheckoutRecoveryFailure.document }
    }
}

extension UFitAPIClient {
    func checkoutOutcome(requestID: String, knownOrderID: String?) async throws -> UFitCheckoutOutcomeDTO {
        let result: UFitCheckoutOutcomeDTO = try await send(UFitCustomerPaymentHTTP.get,
            path: UFitCheckoutRecoveryHTTP.route + requestID, requiresAuth: true, cachePolicy: .reloadIgnoringLocalCacheData)
        try result.validate(requestID: requestID, knownOrderID: knownOrderID)
        return result
    }
}

enum UFitCheckoutRecoveryFailure: LocalizedError {
    case document, localRead, localWrite
    var errorDescription: String? {
        switch self {
        case .document: UFitCheckoutRecoveryCopy.invalid
        case .localRead: UFitCheckoutRecoveryCopy.localRead
        case .localWrite: UFitCheckoutRecoveryCopy.localWrite
        }
    }
}
