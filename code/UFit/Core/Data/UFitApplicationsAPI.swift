import Foundation

private enum ApplicationHTTP {
    static let get = "GET", post = "POST", patch = "PATCH"
    static let countries = "applications/countries", countryPattern = "^[A-Z]{2}$"
    static let base = "applications/", current = "applications/me", admin = "admin/applications/", queue = "admin/applications"
    static let separator = "/", reviews = "/reviews", status = "status", type = "type", cursor = "cursor"
}
private enum ApplicationContractError: LocalizedError {
    case mismatch, countries
    private static let mismatchDescription = String(localized: "Le dossier reçu ne correspond pas à cette candidature. Actualisez pour réessayer.")
    private static let countryDescription = String(localized: "Les pays de candidature sont indisponibles. Rechargez la liste pour continuer.")
    var errorDescription: String? { switch self { case .mismatch: Self.mismatchDescription; case .countries: Self.countryDescription } }
}
struct UFitCurrentApplications: Decodable {
    let creator: UFitApplicationDocument?
    let brand: UFitApplicationDocument?
    let canApplyCreator: Bool
    let canApplyBrand: Bool
}
struct UFitApplicationQueuePage: Decodable { let items: [UFitApplicationQueueItem]; let nextCursor: String? }
private struct CreatorApplicationSubmission: Encodable {
    let displayName: String, email: String, motivation: String
    let portfolioUrl: String?, audienceSummary: String?
    let dossier: UFitCreatorApplicationDossier
    let expectedVersion: Int?
}
private struct BrandApplicationSubmission: Encodable {
    let brandName: String, email: String, websiteUrl: String, productCategory: String, positioning: String
    let dossier: UFitBrandApplicationDossier
    let expectedVersion: Int?
}
extension UFitAPIClient {
    func fetchApplicationCountries(reload: Bool = false) async throws -> [String] {
        struct Reference: Decodable { let countries: [String] }
        let result: Reference = try await fetchReference(path: ApplicationHTTP.countries, reload: reload) { (result: Reference) in
            guard !result.countries.isEmpty, Set(result.countries).count == result.countries.count,
                  result.countries.allSatisfy({ $0.range(of: ApplicationHTTP.countryPattern, options: .regularExpression) != nil }) else { throw ApplicationContractError.countries }
        }
        return result.countries
    }
    func fetchApplications() async throws -> UFitCurrentApplications {
        let result: UFitCurrentApplications = try await send(ApplicationHTTP.get, path: ApplicationHTTP.current, requiresAuth: true)
        if let creator = result.creator { try validateApplication(creator, kind: .creator) }
        if let brand = result.brand { try validateApplication(brand, kind: .brand) }
        return result
    }
    func submitApplication(kind: UFitApplicationKind, values: [UFitApplicationField: String], correcting: UFitApplicationDocument?) async throws -> UFitApplicationDocument {
        let path = ApplicationHTTP.base + kind.collection + (correcting.map { ApplicationHTTP.separator + $0.id } ?? String())
        let method = correcting == nil ? ApplicationHTTP.post : ApplicationHTTP.patch
        func value(_ field: UFitApplicationField) -> String { values[field] ?? String() }
        func optional(_ field: UFitApplicationField) -> String? { let text = value(field); return text.isEmpty ? nil : text }
        let result: UFitApplicationDocument
        switch kind {
        case .creator:
            result = try await send(method, path: path, body: CreatorApplicationSubmission(displayName: value(.name), email: value(.email), motivation: value(.motivation), portfolioUrl: optional(.portfolio), audienceSummary: optional(.audience),
                dossier: UFitCreatorApplicationDossier(instagramUrl: value(.instagram), tiktokUrl: optional(.tiktok), dominantStyle: value(.style), brandsWorn: value(.brandsWorn), outfitExampleUrls: UFitApplicationField.examples.map(value)), expectedVersion: correcting?.metadata.version), requiresAuth: true, publicOutfitsChange: false)
        case .brand:
            result = try await send(method, path: path, body: BrandApplicationSubmission(brandName: value(.name), email: value(.email), websiteUrl: value(.website), productCategory: value(.category), positioning: value(.positioning),
                dossier: UFitBrandApplicationDossier(instagramUrl: value(.instagram), country: value(.country), priceRange: value(.priceRange), lookbookUrl: value(.lookbook), shippingCapabilities: value(.shipping), returnPolicy: value(.returns), commissionProposal: optional(.commission)), expectedVersion: correcting?.metadata.version), requiresAuth: true, publicOutfitsChange: false)
        }
        try validateApplication(result, kind: kind, id: correcting?.id)
        return result
    }
    func fetchApplicationQueue(filter: UFitApplicationQueueFilter, kind: UFitApplicationKind?, cursor: String?) async throws -> UFitApplicationQueuePage {
        var query = [URLQueryItem(name: ApplicationHTTP.status, value: filter.rawValue)]
        if let kind { query.append(URLQueryItem(name: ApplicationHTTP.type, value: kind.rawValue)) }
        if let cursor { query.append(URLQueryItem(name: ApplicationHTTP.cursor, value: cursor)) }
        return try await send(ApplicationHTTP.get, path: ApplicationHTTP.queue, query: query, requiresAuth: true)
    }
    func fetchOwnedApplication(kind: UFitApplicationKind, id: String) async throws -> UFitApplicationDocument {
        guard UUID(uuidString: id) != nil else { throw ApplicationContractError.mismatch }
        let result: UFitApplicationDocument = try await send(ApplicationHTTP.get,
            path: ApplicationHTTP.base + kind.collection + ApplicationHTTP.separator + id, requiresAuth: true)
        try validateApplication(result, kind: kind, id: id)
        return result
    }
    func fetchAdminApplication(kind: UFitApplicationKind, id: String) async throws -> UFitApplicationDocument {
        let result: UFitApplicationDocument = try await send(ApplicationHTTP.get, path: ApplicationHTTP.admin + kind.rawValue + ApplicationHTTP.separator + id, requiresAuth: true)
        try validateApplication(result, kind: kind, id: id)
        return result
    }
    func reviewApplication(_ application: UFitApplicationDocument, decision: UFitApplicationDecision, notes: String?) async throws -> UFitApplicationDocument {
        struct Decision: Encodable { let decision: UFitApplicationDecision; let expectedVersion: Int; let notes: String? }
        let result: UFitApplicationDocument = try await send(ApplicationHTTP.post,
            path: ApplicationHTTP.admin + application.metadata.type.rawValue + ApplicationHTTP.separator + application.id + ApplicationHTTP.reviews,
            body: Decision(decision: decision, expectedVersion: application.metadata.version, notes: notes), requiresAuth: true, publicOutfitsChange: true)
        try validateApplication(result, kind: application.metadata.type, id: application.id)
        return result
    }
    private func validateApplication(_ document: UFitApplicationDocument, kind: UFitApplicationKind, id: String? = nil) throws {
        guard document.metadata.type == kind, document.metadata.version > .zero, UUID(uuidString: document.id) != nil, id == nil || document.id == id else { throw ApplicationContractError.mismatch }
        if case .creator(let payload) = document.payload, let dossier = payload.dossier,
           dossier.outfitExampleUrls.count != UFitApplicationField.examples.count { throw ApplicationContractError.mismatch }
    }
}
