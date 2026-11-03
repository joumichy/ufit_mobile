import Foundation

struct UFitRefundProofReviewDTO: Decodable {
    let decision: UFitRefundProofDecision
    let reason: String
    @UFitRequiredNullable var verificationReference: String?
    let reviewedAt: UFitTimestamp
    private enum CodingKeys: String, CodingKey, CaseIterable {case decision, reason, verificationReference, reviewedAt}
    init(from decoder: Decoder) throws {
        try UFitStrictDecoding.keys(decoder, CodingKeys.self, failure: UFitRefundOrganizationFailure.contract)
        let values = try decoder.container(keyedBy: CodingKeys.self)
        decision = try values.decode(UFitRefundProofDecision.self, forKey: .decision); reason = try values.decode(String.self, forKey: .reason)
        _verificationReference = try values.decode(UFitRequiredNullable<String>.self, forKey: .verificationReference); reviewedAt = try values.decode(UFitTimestamp.self, forKey: .reviewedAt)
        guard UFitServerTextInput.valid(reason, maximum: UFitRefundReviewRules.reasonMaximum), (decision == .reject) == (verificationReference == nil),
              verificationReference == nil || UFitServerTextInput.valid(verificationReference!, maximum: UFitRefundReviewRules.referenceMaximum) else {throw UFitRefundOrganizationFailure.contract}
    }
}
struct UFitExternalRefundSettlementDTO: Decodable {
    let id: String
    let source: String
    let amount: Int
    let currency: String
    let settledOn: String
    let confirmedAt: UFitTimestamp
    private enum CodingKeys: String, CodingKey, CaseIterable {case id, source, amount, currency, settledOn, confirmedAt}
    private enum Contract {static let source = "external_verified", maximumAmount = 2147483647}
    init(from decoder: Decoder) throws {
        try UFitStrictDecoding.keys(decoder, CodingKeys.self, failure: UFitRefundOrganizationFailure.contract)
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(String.self, forKey: .id); source = try values.decode(String.self, forKey: .source)
        amount = try values.decode(Int.self, forKey: .amount); currency = try values.decode(String.self, forKey: .currency)
        settledOn = try values.decode(String.self, forKey: .settledOn); confirmedAt = try values.decode(UFitTimestamp.self, forKey: .confirmedAt)
        guard UUID(uuidString: id) != nil, source == Contract.source, amount > .zero, amount <= Contract.maximumAmount,
              currency.range(of: UFitRefundProofContract.currencyPattern, options: .regularExpression) != nil,
              UFitRefundProofContract.dateValue(settledOn) != nil else {throw UFitRefundOrganizationFailure.contract}
    }
}
struct UFitRefundProofReviewResultDTO: Decodable {
    struct Receipt: Decodable {
        let requestId: String
        let proofId: String
        let decision: UFitRefundProofDecision
    }
    let document: UFitRefundOrganizationDocumentDTO
    let receipt: Receipt
    func validate(reference: UFitRefundRecoveryReference, request: UFitRefundProofReviewRequest) throws {
        try document.validate(scope: .administrator, reference: reference)
        guard receipt.requestId == request.requestId, receipt.proofId == request.proofId, receipt.decision == request.decision else {throw UFitRefundOrganizationFailure.contract}
    }
}
struct UFitRefundProofPageDTO: Decodable {
    let items: [UFitRefundProofDTO]
    @UFitRequiredNullable var nextCursor: String?
    func validate() throws {
        guard items.count <= UFitRefundProofContract.pageSize, Set(items.map(\.id)).count == items.count,
              zip(items, items.dropFirst()).allSatisfy({$0.sequence > $1.sequence}), nextCursor == nil || (nextCursor == items.last?.id && items.count == UFitRefundProofContract.pageSize) else {throw UFitRefundOrganizationFailure.contract}
    }
}
extension UFitAPIClient {
    func reviewRefundProof(reference: UFitRefundRecoveryReference, request: UFitRefundProofReviewRequest) async throws -> UFitRefundProofReviewResultDTO {
        try request.validate()
        let result: UFitRefundProofReviewResultDTO = try await send(UFitRefundOrganizationHTTP.post, path: reviewPath(reference), body: request, requiresAuth: true)
        try result.validate(reference: reference, request: request); return result
    }
    func refundProofReviewReceipt(reference: UFitRefundRecoveryReference, request: UFitRefundProofReviewRequest) async throws -> UFitRefundProofReviewResultDTO {
        let result: UFitRefundProofReviewResultDTO = try await send(UFitRefundOrganizationHTTP.get, path: reviewPath(reference) + UFitRefundOrganizationHTTP.commands + request.requestId, requiresAuth: true)
        try result.validate(reference: reference, request: request); return result
    }
    func refundProofHistory(scope: UFitRefundOrganizationScope, reference: UFitRefundRecoveryReference, cursor: String?) async throws -> UFitRefundProofPageDTO {
        let root = scope == .administrator ? UFitRefundRecoveryHTTP.path : UFitRefundOrganizationHTTP.privateRoot
        var query = [URLQueryItem(name: UFitRefundProofContract.historyLimit, value: String(UFitRefundProofContract.pageSize))]
        if scope != .administrator {query.append(.init(name: UFitRefundOrganizationHTTP.scope, value: scope.rawValue))}
        if let cursor {query.append(.init(name: UFitRefundProofContract.historyCursor, value: cursor))}
        let path = root + UFitRefundProofContract.separator + reference.kind.rawValue + UFitRefundProofContract.separator + reference.id + UFitRefundProofContract.root
        let result: UFitRefundProofPageDTO = try await send(UFitRefundOrganizationHTTP.get, path: path, query: query, requiresAuth: true)
        try result.validate(); return result
    }
    private func reviewPath(_ reference: UFitRefundRecoveryReference) -> String {UFitRefundRecoveryHTTP.path + UFitRefundOrganizationHTTP.separator + reference.kind.rawValue + UFitRefundOrganizationHTTP.separator + reference.id + UFitRefundReviewRules.root}
}
