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
    let id: String
    let brandName: String
    let slug: String
    let bio: String?
    let websiteUrl: String?
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
        return try await send(CommerceHTTP.patch, path: CommerceHTTP.items + itemID, body: Quantity(quantity: quantity), requiresAuth: true)
    }
    func removeCartItem(id: String) async throws -> UFitCartDTO {
        try await send(CommerceHTTP.delete, path: CommerceHTTP.items + id, requiresAuth: true)
    }
    func clearCart() async throws -> UFitCartEnvelope {
        try await send(CommerceHTTP.delete, path: CommerceHTTP.cart, requiresAuth: true)
    }
    func fetchOrders(cursor: String? = nil) async throws -> UFitOrdersPageDTO {
        var query = [URLQueryItem(name: CommerceHTTP.limit, value: String(CommerceHTTP.defaultLimit))]
        if let cursor { query.append(URLQueryItem(name: CommerceHTTP.cursor, value: cursor)) }
        return try await send(CommerceHTTP.get, path: CommerceHTTP.orders, query: query, requiresAuth: true)
    }
    func cancelOrder(id: String) async throws -> UFitOrderDTO {
        try await send("POST", path: CommerceHTTP.orders + "/" + id + "/cancel", requiresAuth: true)
    }
    func resumeOrderPayment(id: String) async throws -> UFitPaymentIntentDTO {
        try await send("POST", path: CommerceHTTP.orders + "/" + id + "/payment", requiresAuth: true)
    }
    func fetchOrder(id: String) async throws -> UFitOrderDTO {
        try await send(CommerceHTTP.get, path: CommerceHTTP.orders + "/" + id, requiresAuth: true)
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
    struct Cancellation: Decodable { let status: String; let outcome: UFitCancellationOutcome? }
    struct Shipment: Decodable {
        let id: String
        let status: UFitShipmentLifecycle
        let carrier: String?
        let trackingNumber: String?
        let trackingUrl: String?
        let shippedAt: String?
        let deliveredAt: String?
    }
    struct Terms: Decodable { let returnPolicy: String }
    let createdAt: String
    let actions: Actions
    let shipment: Shipment?
    let cancellation: Cancellation?
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
