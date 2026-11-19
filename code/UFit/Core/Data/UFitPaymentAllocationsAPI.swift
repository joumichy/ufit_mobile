import Foundation

enum UFitPaymentAllocationHTTP {
    static let get = "GET", post = "POST", root = "admin/payments/", document = "/allocation", prepare = "/allocation-prepare", separator = "/"
    static let algorithm = "source_gross_largest_remainder_v1", missing = 404, persisted = "payment_allocation_persisted_invalid"
    static func validID(_ value: String) -> Bool { UUID(uuidString: value) != nil && value == value.lowercased() }
    static func signedMoney(_ value: Int) -> Bool { (-UFitDecimalInput.maximumInteger...UFitDecimalInput.maximumInteger).contains(value) }
    static func path(_ id: String, suffix: String) throws -> String {
        guard validID(id) else { throw UFitPaymentAllocationFailure.document }; return root + id + suffix
    }
}
enum UFitPaymentAllocationFailure: LocalizedError {
    case document
    var errorDescription: String? { UFitPaymentAllocationCopy.invalid }
}
extension UFitAPIClient {
    func fetchPaymentAllocation(reference: UFitPaymentSettlementDocument, brandID: String) async throws -> UFitPaymentAllocationDocument {
        let document: UFitPaymentAllocationDocument = try await send(UFitPaymentAllocationHTTP.get,
            path: UFitPaymentAllocationHTTP.path(reference.payment.id, suffix: UFitPaymentAllocationHTTP.document),
            requiresAuth: true, cachePolicy: .reloadIgnoringLocalCacheData)
        try document.validate(reference: reference, brandID: brandID); return document
    }
    func preparePaymentAllocation(reference: UFitPaymentSettlementDocument, brandID: String) async throws -> UFitPaymentAllocationDocument {
        struct Request: Encodable {}
        let document: UFitPaymentAllocationDocument = try await send(UFitPaymentAllocationHTTP.post,
            path: UFitPaymentAllocationHTTP.path(reference.payment.id, suffix: UFitPaymentAllocationHTTP.prepare), body: Request(), requiresAuth: true, publicOutfitsChange: false)
        try document.validate(reference: reference, brandID: brandID); return document
    }
}
