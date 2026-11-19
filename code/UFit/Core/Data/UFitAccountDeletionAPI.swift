import Foundation

extension UFitAPIClient {
    func accountDeletionReceipt(_ request: UFitAccountDeletionRequest) async throws -> UFitAccountDeletionReceipt? {
        try request.validate()
        do {
            let receipt: UFitAccountDeletionReceipt = try await send(UFitAccountDeletionHTTP.get,
                path: UFitAccountDeletionHTTP.root + UFitAccountDeletionHTTP.separator + request.id,
                cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, headers: [UFitAccountDeletionHTTP.proofHeader: request.proof])
            try receipt.validate(requestID: request.id); return receipt
        } catch UFitAPIError.requestFailed(let status, _, _) where status == UFitAccountDeletionHTTP.notFound { return nil }
    }
    func requestAccountDeletion(_ request: UFitAccountDeletionRequest) async throws -> UFitAccountDeletionReceipt {
        struct Confirmation: Encodable { let confirmed = true }
        try request.validate()
        let receipt: UFitAccountDeletionReceipt = try await send(UFitAccountDeletionHTTP.put,
            path: UFitAccountDeletionHTTP.root + UFitAccountDeletionHTTP.separator + request.id,
            body: Confirmation(), requiresAuth: true, headers: [UFitAccountDeletionHTTP.proofHeader: request.proof], publicOutfitsChange: true)
        try receipt.validate(requestID: request.id); return receipt
    }
}
