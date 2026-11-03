import Foundation

enum UFitRefundRecoveryHTTP {
    static let get = "GET"; static let path = "admin/refund-recoveries"; static let separator = "/"
    static let limit = "limit"; static let cursor = "cursor"; static let kind = "kind"; static let search = "search"
    static let unauthorized = 401; static let forbidden = 403
    static let pageLimit = 20; static let countLimit = 1; static let searchMaximum = 120
}
enum UFitRefundRecoveryFailure: LocalizedError {
    case document, page, changed, query
    var errorDescription: String? {
        switch self {
        case .document: String(localized: "Le remboursement reçu est incohérent. Actualisez le dossier avant de continuer.")
        case .page: String(localized: "La liste reçue est incohérente. Actualisez les remboursements.")
        case .changed: String(localized: "La file a changé. Actualisez les remboursements avant de continuer.")
        case .query: String(localized: "La référence recherchée est trop longue.")
        }
    }
    static func revoked(_ error: Error) -> Bool {
        guard let error = error as? UFitAPIError else { return false }
        switch error {
        case .authenticationRequired: return true
        case .requestFailed(let status, _, _): return status == UFitRefundRecoveryHTTP.unauthorized || status == UFitRefundRecoveryHTTP.forbidden
        default: return false
        }
    }
    static func missing(_ error: Error) -> Bool {
        guard case UFitAPIError.requestFailed(_, _, let code) = error else { return false }
        return code == Code.missing
    }
    static func message(_ error: Error) -> String {
        if case UFitAPIError.requestFailed(_, _, let code) = error {
            if code == Code.cursor { return UFitRefundRecoveryFailure.changed.localizedDescription }
            if code == Code.missing { return UFitRefundRecoveryCopy.unavailable }
        }
        return error.localizedDescription
    }
    private enum Code { static let cursor = "refund_recovery_cursor_changed"; static let missing = "refund_recovery_not_found" }
}
struct UFitRefundRecoverySummaryDTO: Decodable {
    let kind: UFitRefundRecoveryKind; let id: String; let orderId: String; let brandId: String; let brandName: String; let orderNumber: String
    let amount: Int; let currency: String; let failedAt: UFitTimestamp; let cause: UFitRefundRecoveryCause
    private enum CodingKeys: String, CodingKey, CaseIterable { case kind, id, orderId, brandId, brandName, orderNumber, amount, currency, failedAt, cause }
    init(from decoder: Decoder) throws {
        try UFitStrictDecoding.keys(decoder, CodingKeys.self, failure: UFitRefundRecoveryFailure.document)
        let values = try decoder.container(keyedBy: CodingKeys.self)
        kind = try values.decode(UFitRefundRecoveryKind.self, forKey: .kind); id = try values.decode(String.self, forKey: .id)
        orderId = try values.decode(String.self, forKey: .orderId); brandId = try values.decode(String.self, forKey: .brandId)
        brandName = try values.decode(String.self, forKey: .brandName); orderNumber = try values.decode(String.self, forKey: .orderNumber)
        amount = try values.decode(Int.self, forKey: .amount); currency = try values.decode(String.self, forKey: .currency)
        failedAt = try values.decode(UFitTimestamp.self, forKey: .failedAt); cause = try values.decode(UFitRefundRecoveryCause.self, forKey: .cause)
        guard [id, orderId, brandId].allSatisfy({UUID(uuidString: $0) != nil}), amount > .zero, amount <= UFitDecimalInput.maximumInteger,
              currency.range(of: UFitCurrency.codePattern, options: .regularExpression) != nil,
              !UFitServerTextInput.trimmed(brandName).isEmpty, !UFitServerTextInput.trimmed(orderNumber).isEmpty else { throw UFitRefundRecoveryFailure.document }
    }
    var reference: UFitRefundRecoveryReference { .init(kind: kind, id: id) }

}
struct UFitRefundRecoveryDetailDTO: Decodable {
    enum AttemptState: String, Decodable { case failed, blocked }
    enum ProviderStatus: String, Decodable { case failed }
    struct Attempt: Decodable {
        let id: String; let number: Int; let state: AttemptState
        @UFitRequiredNullable var providerStatus: ProviderStatus?
        @UFitRequiredNullable var refundId: String?
        private enum CodingKeys: String, CodingKey, CaseIterable {case id, number, state, providerStatus, refundId}
        init(from decoder: Decoder) throws {
            try UFitStrictDecoding.keys(decoder, CodingKeys.self, failure: UFitRefundRecoveryFailure.document)
            let values = try decoder.container(keyedBy: CodingKeys.self)
            id = try values.decode(String.self, forKey: .id); number = try values.decode(Int.self, forKey: .number)
            state = try values.decode(AttemptState.self, forKey: .state)
            _providerStatus = try values.decode(UFitRequiredNullable<ProviderStatus>.self, forKey: .providerStatus)
            _refundId = try values.decode(UFitRequiredNullable<String>.self, forKey: .refundId)
        }
    }
    let summary: UFitRefundRecoverySummaryDTO
    let attempt: Attempt
    private enum CodingKeys: String, CodingKey, CaseIterable { case summary, attempt }
    init(from decoder: Decoder) throws {
        try UFitStrictDecoding.keys(decoder, CodingKeys.self, failure: UFitRefundRecoveryFailure.document)
        let values = try decoder.container(keyedBy: CodingKeys.self)
        summary = try values.decode(UFitRefundRecoverySummaryDTO.self, forKey: .summary)
        attempt = try values.decode(Attempt.self, forKey: .attempt)
        guard UUID(uuidString: attempt.id) != nil, attempt.number >= UFitRefundRecoveryHTTP.countLimit else { throw UFitRefundRecoveryFailure.document }
        switch attempt.state {
        case .failed: guard summary.cause == .failed, attempt.providerStatus == .failed, let id = attempt.refundId, !id.isEmpty else { throw UFitRefundRecoveryFailure.document }
        case .blocked: guard summary.cause == .blocked, attempt.providerStatus == nil, attempt.refundId == nil else { throw UFitRefundRecoveryFailure.document }
        }
    }
}
struct UFitRefundRecoveryPageDTO: Decodable {
    let items: [UFitRefundRecoverySummaryDTO]; let totalCount: Int
    @UFitRequiredNullable var nextCursor: String?
    private enum CodingKeys: String, CodingKey, CaseIterable { case items, totalCount, nextCursor }
    init(from decoder: Decoder) throws {
        try UFitStrictDecoding.keys(decoder, CodingKeys.self, failure: UFitRefundRecoveryFailure.page)
        let values = try decoder.container(keyedBy: CodingKeys.self)
        items = try values.decode([UFitRefundRecoverySummaryDTO].self, forKey: .items); totalCount = try values.decode(Int.self, forKey: .totalCount)
        _nextCursor = try values.decode(UFitRequiredNullable<String>.self, forKey: .nextCursor)
        guard totalCount >= items.count, Set(items.map(\.reference)).count == items.count,
              nextCursor == nil || (!items.isEmpty && !UFitServerTextInput.trimmed(nextCursor!).isEmpty) else { throw UFitRefundRecoveryFailure.page }
    }
}
extension UFitAPIClient {
    func fetchRefundRecoveries(kind: UFitRefundRecoveryKind? = nil, search: String? = nil, cursor: String? = nil, limit: Int = UFitRefundRecoveryHTTP.pageLimit) async throws -> UFitRefundRecoveryPageDTO {
        var query = [URLQueryItem(name: UFitRefundRecoveryHTTP.limit, value: String(limit))]
        if let kind {query.append(.init(name: UFitRefundRecoveryHTTP.kind, value: kind.rawValue))}
        if let cursor {query.append(.init(name: UFitRefundRecoveryHTTP.cursor, value: cursor))}
        if let search, !search.isEmpty {guard search.utf16.count <= UFitRefundRecoveryHTTP.searchMaximum else {throw UFitRefundRecoveryFailure.query}; query.append(.init(name: UFitRefundRecoveryHTTP.search, value: search))}
        let page: UFitRefundRecoveryPageDTO = try await send(UFitRefundRecoveryHTTP.get, path: UFitRefundRecoveryHTTP.path, query: query, requiresAuth: true)
        guard page.items.count <= limit, cursor != nil || page.totalCount <= page.items.count || page.nextCursor != nil else {throw UFitRefundRecoveryFailure.page}
        return page
    }
    func fetchRefundRecovery(_ reference: UFitRefundRecoveryReference) async throws -> UFitRefundRecoveryDetailDTO {
        let result: UFitRefundRecoveryDetailDTO = try await send(UFitRefundRecoveryHTTP.get, path: UFitRefundRecoveryHTTP.path + UFitRefundRecoveryHTTP.separator + reference.kind.rawValue + UFitRefundRecoveryHTTP.separator + reference.id, requiresAuth: true)
        guard result.summary.reference == reference else {throw UFitRefundRecoveryFailure.document}; return result
    }
}
