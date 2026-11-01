import Foundation

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
    let taxNotice: String
    let customsNotice: String
}
extension UFitAPIClient {
    func fetchCommercePolicy(brandID: String) async throws -> UFitBrandCommercePolicy? {
        try await send("GET", path: "public/brands/" + brandID + "/commerce-policy")
    }
    func quoteCart(country: String) async throws -> UFitCartQuoteDTO {
        struct Destination: Encodable { let country: String }
        return try await send("POST", path: "cart/quote", body: Destination(country: country), requiresAuth: true)
    }
}
