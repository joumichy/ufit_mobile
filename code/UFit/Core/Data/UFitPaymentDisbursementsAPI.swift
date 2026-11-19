import Foundation

enum UFitPaymentDisbursementHTTP {
    static let get = "GET", post = "POST", root = "admin/payments/", document = "/disbursements", resume = "/disbursements-resume"
    static let algorithm = "original_share_cumulative_return_v1", missing = 404
    static let transferPattern = "^tr_[A-Za-z0-9_]+$", reversalPattern = "^trr_[A-Za-z0-9_]+$"
    static let pollInterval = Duration.seconds(3)
    static func path(_ id: String, suffix: String) throws -> String {
        guard UFitPaymentAllocationHTTP.validID(id) else { throw UFitPaymentDisbursementFailure.document }; return root + id + suffix
    }
}
enum UFitPaymentDisbursementFailure: LocalizedError {
    case document
    var errorDescription: String? { UFitPaymentDisbursementCopy.invalid }
}
extension UFitAPIClient {
    func fetchPaymentDisbursements(reference: UFitPaymentSettlementDocument, brandID: String) async throws -> UFitPaymentDisbursementDocument {
        let document: UFitPaymentDisbursementDocument = try await send(UFitPaymentDisbursementHTTP.get,
            path: UFitPaymentDisbursementHTTP.path(reference.payment.id, suffix: UFitPaymentDisbursementHTTP.document), requiresAuth: true, cachePolicy: .reloadIgnoringLocalCacheData)
        try document.validate(reference: reference, brandID: brandID); return document
    }
    func resumePaymentDisbursements(reference: UFitPaymentSettlementDocument, brandID: String) async throws -> UFitPaymentDisbursementDocument {
        struct Request: Encodable {}
        let document: UFitPaymentDisbursementDocument = try await send(UFitPaymentDisbursementHTTP.post,
            path: UFitPaymentDisbursementHTTP.path(reference.payment.id, suffix: UFitPaymentDisbursementHTTP.resume), body: Request(), requiresAuth: true, publicOutfitsChange: false)
        try document.validate(reference: reference, brandID: brandID); return document
    }
}
