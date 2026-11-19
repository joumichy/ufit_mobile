import Foundation

enum UFitBrandCommerceHTTP {
    static let get = "GET"; static let put = "PUT"; static let root = "brands/"; static let suffix = "/commerce-policy"
    static let metadata = "brands/commerce-policy/metadata"
}
enum UFitBrandCommerceContractError: LocalizedError {
    case document, metadata
    var errorDescription: String? {
        switch self {
        case .document: String(localized: "Les conditions reçues sont incohérentes. Actualisez avant de continuer.")
        case .metadata: String(localized: "Les pays et devises sont indisponibles. Rechargez-les avant de continuer.")
        }
    }
}
struct UFitBrandCommerceMetadata: Decodable {
    let countries: [String]
    let currencies: [UFitCurrency]
    func validate() throws {
        guard !countries.isEmpty, Set(countries).count == countries.count,
              countries.allSatisfy({ $0.range(of: UFitCountry.codePattern, options: .regularExpression) != nil }),
              !currencies.isEmpty, Set(currencies.map(\.code)).count == currencies.count,
              currencies.allSatisfy({ $0.code.range(of: UFitCurrency.codePattern, options: .regularExpression) != nil && $0.minorUnitDigits >= .zero }) else { throw UFitBrandCommerceContractError.metadata }
    }
    var choices: [UFitCountry] {
        countries.map { .init(id: $0, name: Self.locale.localizedString(forRegionCode: $0) ?? $0) }.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
    }
    private static let locale = Locale(identifier: "fr_CH")
}
struct UFitManagedBrandCommercePolicy: Decodable {
    let brandId: String
    let version: Int
    @UFitRequiredNullable var policy: UFitBrandCommercePolicy?
    func validate(brandID: String) throws {
        guard UUID(uuidString: brandId) != nil, brandId == brandID,
              (UFitBrandCommerceInput.unconfiguredVersion...UFitBrandCommerceInput.maximumVersion).contains(version),
              (version == UFitBrandCommerceInput.unconfiguredVersion) == (policy == nil) else { throw UFitBrandCommerceContractError.document }
    }
}
extension UFitAPIClient {
    func fetchBrandCommerceMetadata(reload: Bool = false) async throws -> UFitBrandCommerceMetadata {
        try await fetchReference(path: UFitBrandCommerceHTTP.metadata, reload: reload) { (result: UFitBrandCommerceMetadata) in
            try result.validate()
        }
    }
    func fetchManagedBrandCommercePolicy(brandID: String) async throws -> UFitManagedBrandCommercePolicy {
        let result: UFitManagedBrandCommercePolicy = try await send(UFitBrandCommerceHTTP.get, path: UFitBrandCommerceHTTP.root + brandID + UFitBrandCommerceHTTP.suffix, requiresAuth: true)
        try result.validate(brandID: brandID); return result
    }
    func saveBrandCommercePolicy(brandID: String, version: Int, policy: UFitBrandCommercePolicy) async throws -> UFitManagedBrandCommercePolicy {
        struct Body: Encodable { let expectedVersion: Int; let policy: UFitBrandCommercePolicy }
        let result: UFitManagedBrandCommercePolicy = try await send(UFitBrandCommerceHTTP.put, path: UFitBrandCommerceHTTP.root + brandID + UFitBrandCommerceHTTP.suffix,
            body: Body(expectedVersion: version, policy: policy), requiresAuth: true, publicOutfitsChange: false)
        try result.validate(brandID: brandID)
        guard version < UFitBrandCommerceInput.maximumVersion, result.version == version + UFitBrandCommerceInput.versionStep, result.policy != nil else { throw UFitBrandCommerceContractError.document }
        return result
    }
}
private enum UFitBrandCommerceFailureCode: String {
    case changed = "brand_policy_version_changed", access = "brand_policy_access_required", invalid = "brand_policy_invalid"
}
extension UFitAPIError {
    var brandCommerceFailureDescription: String? {
        guard case .requestFailed(_, _, let raw) = self, let raw, let code = UFitBrandCommerceFailureCode(rawValue: raw) else { return nil }
        switch code {
        case .changed: return String(localized: "Ces conditions ont changé. Votre saisie est conservée ; actualisez avant de recommencer.")
        case .access: return String(localized: "Votre accès à cette marque a changé. Revenez aux espaces et actualisez.")
        case .invalid: return nil
        }
    }
    var isInvalidBrandCommercePolicy: Bool {
        if case .requestFailed(_, _, let raw) = self { raw == UFitBrandCommerceFailureCode.invalid.rawValue } else { false }
    }
}
