import Foundation

enum UFitCheckoutHTTP {
    static let post = "POST"
    static let reviewRoute = "orders/checkout-review"
    static let outcomeRoute = "orders/checkout-requests/"
    static let invalid = "checkout_recovery_invalid"
    static let quoteChanged = "checkout_quote_changed"
    static let commissionUnavailable = "commission_rule_unconfigured"
    static let fingerprintPattern = "^[a-f0-9]{64}$"
}

struct UFitCheckoutReviewDTO: Decodable {
    let quote: UFitCartQuoteDTO
    let available: Bool
    func validate(cart: UFitCartDTO, country: String) throws {
        let maximum = UFitCustomerPaymentHTTP.maximum
        guard quote.cartId == cart.id, quote.brandId == cart.brandId, quote.country == country,
              quote.currency == cart.currency, UUID(uuidString: quote.cartId) != nil, UUID(uuidString: quote.brandId) != nil,
              quote.currency.range(of: UFitCurrency.codePattern, options: .regularExpression) != nil,
              country.range(of: UFitCountry.codePattern, options: .regularExpression) != nil,
              quote.fingerprint.range(of: UFitCheckoutHTTP.fingerprintPattern, options: .regularExpression) != nil,
              !quote.items.isEmpty, quote.items.count == cart.items.count,
              Set(quote.items.map(\.id)).count == quote.items.count,
              quote.subtotalAmount >= .zero, quote.subtotalAmount <= maximum,
              quote.shippingAmount >= .zero, quote.shippingAmount <= maximum,
              quote.taxAmount >= .zero, quote.taxAmount <= maximum,
              quote.totalAmount > .zero, quote.totalAmount <= maximum,
              quote.totalAmount == quote.subtotalAmount + quote.shippingAmount + quote.taxAmount else {
            throw UFitCheckoutReviewFailure.invalid
        }
        var subtotal = Int.zero
        for item in quote.items {
            guard let expected = cart.items.first(where: { $0.id == item.id }), UUID(uuidString: item.id) != nil,
                  UUID(uuidString: item.productId) != nil, UUID(uuidString: item.productVariantId) != nil,
                  item.productId == expected.productId, item.productVariantId == expected.productVariantId,
                  item.quantity == expected.quantity, item.quantity > .zero, item.quantity <= maximum,
                  item.unitPrice >= .zero, item.unitPrice <= maximum else { throw UFitCheckoutReviewFailure.invalid }
            let amount = item.unitPrice * item.quantity
            guard amount <= maximum, subtotal + amount <= maximum else { throw UFitCheckoutReviewFailure.invalid }
            subtotal += amount
        }
        guard subtotal == quote.subtotalAmount else { throw UFitCheckoutReviewFailure.invalid }
    }
}

enum UFitCheckoutReviewFailure: LocalizedError {
    case invalid
    var errorDescription: String? { UFitCheckoutAvailabilityCopy.failed }
}

struct UFitCartQuoteDTO: Decodable {
    struct Item: Decodable {
        let id: String
        let productId: String
        let productVariantId: String
        let quantity: Int
        let unitPrice: Int
    }
    let items: [Item]
    let fingerprint: String
    let cartId: String
    let brandId: String
    let country: String
    let currency: String
    let subtotalAmount: Int
    let shippingAmount: Int
    let taxAmount: Int
    let totalAmount: Int
    let returnWindowDays: Int
    let returnPolicy: String
    let refundPolicyCode: UFitRefundPolicy
    let taxNotice: String
    let customsNotice: String
}
extension UFitAPIClient {
    func fetchCommercePolicy(brandID: String) async throws -> UFitBrandCommercePolicy? {
        try await send("GET", path: "public/brands/" + brandID + "/commerce-policy")
    }
    func reviewCheckout(cart: UFitCartDTO, country: String) async throws -> UFitCheckoutReviewDTO {
        struct Destination: Encodable { let country: String }
        let result: UFitCheckoutReviewDTO = try await send(UFitCheckoutHTTP.post, path: UFitCheckoutHTTP.reviewRoute,
            body: Destination(country: country), requiresAuth: true)
        try result.validate(cart: cart, country: country)
        return result
    }
}
