import Foundation

enum UFitDistributionHTTP {
    static let get = "GET", put = "PUT", root = "admin/payment-distribution/brands", separator = "/", history = "/history", changes = "/changes/"
    static let search = "search", cursor = "cursor", limit = "limit"
    static let pageSize = 20, firstRevision = 1, maximumRevision = 2147483647, basisPoints = 10000, rateDigits = 2, reasonMaximum = 500, searchMaximum = 120
    static let unauthorized = 401, forbidden = 403, missing = 404, badInput = 400, changed = 409
    static let changeMissing = "payment_distribution_change_missing", brandMissing = "payment_distribution_brand_missing"
    static let conflict = "payment_distribution_changed", reused = "payment_distribution_request_reused"
    static let searchDebounce = Duration.milliseconds(250)
    static func validID(_ id: String) -> Bool { UUID(uuidString: id) != nil && id == id.lowercased() }
    static func path(_ id: String) throws -> String {
        guard validID(id) else { throw UFitDistributionBoundaryFailure.document }
        return root + separator + id
    }
}
extension UFitAPIClient {
    func fetchDistributionBrands(search: String, cursor: String?) async throws -> UFitDistributionBrandPage {
        let term = UFitServerTextInput.trimmed(search)
        guard term.utf16.count <= UFitDistributionHTTP.searchMaximum, cursor.map(UFitDistributionHTTP.validID) ?? true else { throw UFitDistributionBoundaryFailure.document }
        var query = [URLQueryItem(name: UFitDistributionHTTP.limit, value: String(UFitDistributionHTTP.pageSize))]
        if !term.isEmpty { query.append(.init(name: UFitDistributionHTTP.search, value: term)) }
        if let cursor { query.append(.init(name: UFitDistributionHTTP.cursor, value: cursor)) }
        let result: UFitDistributionBrandPage = try await send(UFitDistributionHTTP.get, path: UFitDistributionHTTP.root, query: query,
            requiresAuth: true, cachePolicy: .reloadIgnoringLocalCacheData)
        try result.validate(after: cursor); return result
    }
    func fetchDistribution(brandID: String) async throws -> UFitDistributionDocument {
        let result: UFitDistributionDocument = try await send(UFitDistributionHTTP.get, path: UFitDistributionHTTP.path(brandID),
            requiresAuth: true, cachePolicy: .reloadIgnoringLocalCacheData)
        try result.validate(brandID: brandID); return result
    }
    func fetchDistributionHistory(brandID: String, cursor: String?, after revision: Int?) async throws -> UFitDistributionHistoryPage {
        guard cursor.map(UFitDistributionHTTP.validID) ?? true else { throw UFitDistributionBoundaryFailure.document }
        var query = [URLQueryItem(name: UFitDistributionHTTP.limit, value: String(UFitDistributionHTTP.pageSize))]
        if let cursor { query.append(.init(name: UFitDistributionHTTP.cursor, value: cursor)) }
        let result: UFitDistributionHistoryPage = try await send(UFitDistributionHTTP.get,
            path: UFitDistributionHTTP.path(brandID) + UFitDistributionHTTP.history, query: query, requiresAuth: true, cachePolicy: .reloadIgnoringLocalCacheData)
        try result.validate(brandID: brandID, after: revision); return result
    }
    func reviseDistribution(brandID: String, body: UFitDistributionChangeBody, previousID: String?) async throws -> UFitDistributionChangeResult {
        try body.validate(previousID: previousID)
        let result: UFitDistributionChangeResult = try await send(UFitDistributionHTTP.put, path: UFitDistributionHTTP.path(brandID), body: body, requiresAuth: true)
        try result.validate(brandID: brandID, body: body, previousID: previousID); return result
    }
    func fetchDistributionChange(brandID: String, body: UFitDistributionChangeBody, previousID: String?) async throws -> UFitDistributionChangeResult {
        try body.validate(previousID: previousID)
        guard UFitDistributionHTTP.validID(body.requestId) else { throw UFitDistributionBoundaryFailure.document }
        let result: UFitDistributionChangeResult = try await send(UFitDistributionHTTP.get,
            path: UFitDistributionHTTP.path(brandID) + UFitDistributionHTTP.changes + body.requestId,
            requiresAuth: true, cachePolicy: .reloadIgnoringLocalCacheData)
        try result.validate(brandID: brandID, body: body, previousID: previousID); return result
    }
}
