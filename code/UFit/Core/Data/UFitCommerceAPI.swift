import Foundation

private enum CommerceHTTP {
    static let get = "GET"
    static let patch = "PATCH"
    static let delete = "DELETE"
    static let cart = "cart"
    static let items = "cart/items/"
    static let orders = "orders"
    static let limit = "limit"
    static let cursor = "cursor"
    static let defaultLimit = 20
}

struct UFitPublicBrandDTO: Decodable {
    struct Stats: Decodable { let publishedOutfits: Int; let activeProducts: Int }
    let id: String
    @UFitRequiredNullable var logoUrl: String?
    let brandName: String
    let slug: String
    let bio: String?
    let websiteUrl: String?
    let stats: Stats
}

extension UFitAPIClient {
    func fetchPublicBrand(id: String) async throws -> UFitPublicBrandDTO {
        let route = "public/brands/"
        return try await send(CommerceHTTP.get, path: route + id)
    }

    func fetchCart() async throws -> UFitCartEnvelope {
        try await send(CommerceHTTP.get, path: CommerceHTTP.cart, requiresAuth: true)
    }
    func setCartQuantity(itemID: String, quantity: Int) async throws -> UFitCartDTO {
        struct Quantity: Encodable { let quantity: Int }
        return try await send(CommerceHTTP.patch, path: CommerceHTTP.items + itemID, body: Quantity(quantity: quantity), requiresAuth: true, publicOutfitsChange: false)
    }
    func removeCartItem(id: String) async throws -> UFitCartDTO {
        try await send(CommerceHTTP.delete, path: CommerceHTTP.items + id, requiresAuth: true, publicOutfitsChange: false)
    }
    func clearCart() async throws -> UFitCartEnvelope {
        try await send(CommerceHTTP.delete, path: CommerceHTTP.cart, requiresAuth: true, publicOutfitsChange: false)
    }
    func fetchOrders(cursor: String? = nil) async throws -> UFitOrdersPageDTO {
        var query = [URLQueryItem(name: CommerceHTTP.limit, value: String(CommerceHTTP.defaultLimit))]
        if let cursor { query.append(URLQueryItem(name: CommerceHTTP.cursor, value: cursor)) }
        let result: UFitOrdersPageDTO = try await send(CommerceHTTP.get, path: CommerceHTTP.orders, query: query, requiresAuth: true)
        try result.items.forEach {try $0.cancellation?.validateSettlement(amount: $0.totalAmount, currency: $0.currency)}
        return result
    }
    func cancelOrder(id: String) async throws -> UFitOrderDTO {
        let result: UFitOrderDTO = try await send("POST", path: CommerceHTTP.orders + "/" + id + "/cancel", requiresAuth: true, publicOutfitsChange: false)
        try result.cancellation?.validateSettlement(amount: result.totalAmount, currency: result.currency); return result
    }
    func fetchOrder(id: String) async throws -> UFitOrderDTO {
        let result: UFitOrderDTO = try await send(CommerceHTTP.get, path: CommerceHTTP.orders + "/" + id, requiresAuth: true)
        try result.cancellation?.validateSettlement(amount: result.totalAmount, currency: result.currency); return result
    }
}

struct UFitCartEnvelope: Decodable { let cart: UFitCartDTO? }
struct UFitCartLineDTO: Decodable, Identifiable {
    let id: String
    let productId: String
    let productVariantId: String
    let quantity: Int
    let unitPrice: Int
    let currency: String
    let brandId: String
    let sourceOutfitId: String?
    let sourceCreatorId: String?
}
struct UFitProductImageDTO: Decodable {
    let url: String
    let position: Int
    let kind: String
}
struct UFitOrdersPageDTO: Decodable {
    let items: [UFitOrderDTO]
    let nextCursor: String?
}
struct UFitOrderDTO: Decodable, Identifiable {
    struct Actions: Decodable { let cancel: Bool; let resumePayment: Bool }
    struct Shipment: Decodable {
        let id: String
        let status: UFitShipmentLifecycle
        let carrier: String?
        let trackingNumber: String?
        let trackingUrl: String?
        let shippedAt: String?
        let deliveredAt: String?
        let incidentReason: String?
        let incidentAt: UFitTimestamp?
    }
    struct Terms: Decodable { let returnPolicy: String }
    let createdAt: String
    let actions: Actions
    let shipment: Shipment?
    let cancellation: UFitOrderCancellationDTO?
    let commerceSnapshot: Terms?
    let id: String
    let orderNumber: String
    let status: UFitOrderLifecycle
    let brandId: String
    let subtotalAmount: Int
    let shippingAmount: Int
    let taxAmount: Int
    let totalAmount: Int
    let currency: String
    let shippingAddress: UFitShippingAddress
    let items: [UFitOrderItemDTO]
}
struct UFitOrderItemDTO: Decodable, Identifiable {
    struct Snapshot: Decodable {
        let name: String
        let size: String?
        let color: String?
        let imageUrl: String?
    }
    let id: String
    let productId: String
    let productVariantId: String
    let productSnapshot: Snapshot
    let quantity: Int
    let unitPrice: Int
    let totalPrice: Int
}

struct UFitOrderCancellationDTO: Decodable {
    struct Refund: Decodable {
        let state: UFitCancellationRefundLifecycle
        @UFitRequiredNullable var providerStatus: UFitCancellationRefundProviderStatus?
    }
    let id: String
    let status: UFitCancellationLifecycle
    let reason: UFitCancellationReason
    @UFitRequiredNullable var outcome: UFitCancellationOutcome?
    @UFitRequiredNullable var refund: Refund?
    @UFitRequiredNullable var externalSettlement: UFitExternalRefundSettlementDTO?
    private enum CodingKeys: String, CodingKey { case id, status, reason, outcome, refund, externalSettlement }
    func validateSettlement(amount: Int, currency: String) throws {
        if let externalSettlement {guard externalSettlement.amount == amount, externalSettlement.currency == currency else {throw UFitCancellationContractError.document}}
    }
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(String.self, forKey: .id)
        guard UUID(uuidString: id) != nil else {throw UFitCancellationContractError.document}
        status = try values.decode(UFitCancellationLifecycle.self, forKey: .status)
        reason = try values.decode(UFitCancellationReason.self, forKey: .reason)
        _outcome = try values.decode(UFitRequiredNullable<UFitCancellationOutcome>.self, forKey: .outcome)
        _refund = try values.decode(UFitRequiredNullable<Refund>.self, forKey: .refund)
        _externalSettlement = try values.decode(UFitRequiredNullable<UFitExternalRefundSettlementDTO>.self, forKey: .externalSettlement)
        if outcome == .refundedExternally {
            guard externalSettlement != nil, status == .succeeded, let refund,
                  (refund.state == .failed && refund.providerStatus == .failed) || (refund.state == .blocked && refund.providerStatus == nil) else {throw UFitCancellationContractError.document}
            return
        }
        guard externalSettlement == nil else {throw UFitCancellationContractError.document}
        let expectedOutcome: UFitCancellationOutcome?
        if let refund {
            switch (refund.state, refund.providerStatus) {
            case (.queued, nil), (.pending, .pending), (.pending, .requiresAction): expectedOutcome = nil
            case (.succeeded, .succeeded): expectedOutcome = .refunded
            case (.failed, .failed): expectedOutcome = .refundFailed
            case (.failed, .cancelled): expectedOutcome = .refundCancelled
            case (.blocked, nil): expectedOutcome = .refundBlocked
            default: throw UFitCancellationContractError.document
            }
        } else {
            guard outcome == nil || outcome == .notCharged else { throw UFitCancellationContractError.document }
            expectedOutcome = outcome
        }
        guard outcome == expectedOutcome else { throw UFitCancellationContractError.document }
        switch status {
        case .requested: guard outcome != .notCharged else { throw UFitCancellationContractError.document }
        case .succeeded: guard outcome == .notCharged || outcome == .refunded else { throw UFitCancellationContractError.document }
        case .failed: guard outcome == .refundFailed || outcome == .refundCancelled || outcome == .refundBlocked else { throw UFitCancellationContractError.document }
        }
    }
}
enum UFitCancellationContractError: LocalizedError {
    case document
    var errorDescription: String? { String(localized: "Le statut du remboursement reçu est incohérent. Actualisez la commande avant de continuer.") }
}
