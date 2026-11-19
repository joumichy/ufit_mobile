import Foundation

private enum CommissionRulesHTTP {
    static let get = "GET"; static let post = "POST"
    static let root = "admin/commission-rules"; static let options = "/options/"; static let history = "/history"; static let revisions = "/revisions"; static let separator = "/"
    static let limit = "limit"; static let cursor = "cursor"; static let brand = "brandId"; static let search = "search"
    static let maximumSearch = 100
    static func page(cursor: String?) -> [URLQueryItem] {
        var values = [URLQueryItem(name: limit, value: String(UFitCommissionRuleContract.pageLimit))]
        if let cursor { values.append(URLQueryItem(name: Self.cursor, value: cursor)) }
        return values
    }
    static func optionQuery(brandID: String? = nil, cursor: String?, search: String) throws -> [URLQueryItem] {
        let search = UFitServerTextInput.trimmed(search)
        guard search.utf16.count <= maximumSearch else { throw UFitCommissionRuleFailure.input }
        var query = page(cursor: cursor)
        if let brandID { query.append(URLQueryItem(name: brand, value: brandID)) }
        if !search.isEmpty { query.append(URLQueryItem(name: Self.search, value: search)) }
        return query
    }
}
extension UFitAPIClient {
    func fetchCommissionRules(brandID: String? = nil, cursor: String? = nil) async throws -> UFitCommissionRulePageDTO {
        var query = CommissionRulesHTTP.page(cursor: cursor)
        if let brandID { query.append(URLQueryItem(name: CommissionRulesHTTP.brand, value: brandID)) }
        let result: UFitCommissionRulePageDTO = try await send(CommissionRulesHTTP.get, path: CommissionRulesHTTP.root, query: query, requiresAuth: true)
        try result.validate(cursor: cursor, brandID: brandID); return result
    }
    func fetchCommissionRule(scopeID: String) async throws -> UFitCommissionRuleDTO {
        let result: UFitCommissionRuleDTO = try await send(CommissionRulesHTTP.get, path: CommissionRulesHTTP.root + CommissionRulesHTTP.separator + scopeID, requiresAuth: true)
        guard result.scopeId == scopeID, result.supersededAt == nil else { throw UFitCommissionRuleFailure.document }; return result
    }
    func fetchCommissionRuleHistory(scopeID: String, cursor: String? = nil) async throws -> UFitCommissionRulePageDTO {
        let result: UFitCommissionRulePageDTO = try await send(CommissionRulesHTTP.get, path: CommissionRulesHTTP.root + CommissionRulesHTTP.separator + scopeID + CommissionRulesHTTP.history,
            query: CommissionRulesHTTP.page(cursor: cursor), requiresAuth: true)
        try result.validate(cursor: cursor, historyScopeID: scopeID); return result
    }
    func createCommissionRule(brandID: String, productID: String?, gradeCode: String?, configuration: UFitCommissionRuleConfiguration, actorID: String) async throws -> UFitCommissionRuleDTO {
        try configuration.validate()
        let body = CreateRule(brandId: brandID, productId: productID, creatorGradeCode: gradeCode, configuration: configuration)
        let result: UFitCommissionRuleDTO = try await send(CommissionRulesHTTP.post, path: CommissionRulesHTTP.root, body: body, requiresAuth: true, publicOutfitsChange: false)
        guard result.matches(brandID: brandID, productID: productID, gradeCode: gradeCode, configuration: configuration), result.createdByUserId == actorID,
              result.revision == UFitCommissionRuleContract.initialRevision, result.previousRuleId == nil, result.supersededAt == nil else { throw UFitCommissionRuleFailure.document }; return result
    }
    func reviseCommissionRule(_ current: UFitCommissionRuleDTO, configuration: UFitCommissionRuleConfiguration, actorID: String) async throws -> UFitCommissionRuleDTO {
        try configuration.validate()
        guard current.revision < UFitCommissionRuleContract.maximumRevision else { throw UFitCommissionRuleFailure.input }
        let body = ReviseRule(expectedRevision: current.revision, configuration: configuration)
        let result: UFitCommissionRuleDTO = try await send(CommissionRulesHTTP.post, path: CommissionRulesHTTP.root + CommissionRulesHTTP.separator + current.scopeId + CommissionRulesHTTP.revisions, body: body, requiresAuth: true, publicOutfitsChange: false)
        guard result.scopeId == current.scopeId, result.previousRuleId == current.id, result.id != current.id, result.createdByUserId == actorID,
              result.revision == current.revision + UFitCommissionRuleContract.revisionStep, result.supersededAt == nil,
              result.matches(brandID: current.brandId, productID: current.productId, gradeCode: current.creatorGradeCode, configuration: configuration) else { throw UFitCommissionRuleFailure.document }; return result
    }
    func fetchCommissionBrands(cursor: String? = nil, search: String = String()) async throws -> UFitCommissionOptionPageDTO<UFitCommissionBrandOption> {
        let result: UFitCommissionOptionPageDTO<UFitCommissionBrandOption> = try await send(CommissionRulesHTTP.get,
            path: CommissionRulesHTTP.root + CommissionRulesHTTP.options + UFitCommissionOptionKind.brands.rawValue,
            query: CommissionRulesHTTP.optionQuery(cursor: cursor, search: search), requiresAuth: true)
        try result.validate(cursor: cursor); return result
    }
    func fetchCommissionGrades(cursor: String? = nil, search: String = String()) async throws -> UFitCommissionOptionPageDTO<UFitCommissionGradeOption> {
        let result: UFitCommissionOptionPageDTO<UFitCommissionGradeOption> = try await send(CommissionRulesHTTP.get,
            path: CommissionRulesHTTP.root + CommissionRulesHTTP.options + UFitCommissionOptionKind.grades.rawValue,
            query: CommissionRulesHTTP.optionQuery(cursor: cursor, search: search), requiresAuth: true)
        try result.validate(cursor: cursor); return result
    }
    func fetchCommissionProducts(brandID: String, cursor: String? = nil, search: String = String()) async throws -> UFitCommissionOptionPageDTO<UFitCommissionProductOption> {
        let result: UFitCommissionOptionPageDTO<UFitCommissionProductOption> = try await send(CommissionRulesHTTP.get,
            path: CommissionRulesHTTP.root + CommissionRulesHTTP.options + UFitCommissionOptionKind.products.rawValue,
            query: CommissionRulesHTTP.optionQuery(brandID: brandID, cursor: cursor, search: search), requiresAuth: true)
        try result.validate(cursor: cursor)
        guard result.items.allSatisfy({ $0.brandId == brandID }) else { throw UFitCommissionRuleFailure.document }; return result
    }
}
private struct CreateRule: Encodable {
    let brandId: String; let productId: String?; let creatorGradeCode: String?; let configuration: UFitCommissionRuleConfiguration
    private enum CodingKeys: String, CodingKey { case brandId, productId, creatorGradeCode }
    func encode(to encoder: Encoder) throws {
        try configuration.encode(to: encoder)
        var value = encoder.container(keyedBy: CodingKeys.self)
        try value.encode(brandId, forKey: .brandId); try value.encode(productId, forKey: .productId); try value.encode(creatorGradeCode, forKey: .creatorGradeCode)
    }
}
private struct ReviseRule: Encodable {
    let expectedRevision: Int; let configuration: UFitCommissionRuleConfiguration
    private enum CodingKeys: String, CodingKey { case expectedRevision }
    func encode(to encoder: Encoder) throws {
        try configuration.encode(to: encoder)
        var value = encoder.container(keyedBy: CodingKeys.self); try value.encode(expectedRevision, forKey: .expectedRevision)
    }
}
