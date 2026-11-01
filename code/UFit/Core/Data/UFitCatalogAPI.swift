import Foundation

enum UFitCatalogHTTP {
    static let get = "GET"; static let post = "POST"; static let put = "PUT"; static let patch = "PATCH"
    static let collection = "products"; static let base = "products/"; static let metadata = "products/metadata"
    static let privateSuffix = "/private"; static let creation = "products/creation-requests/"
    static let brandQuery = "brandId"; static let statusQuery = "status"; static let cursorQuery = "cursor"; static let limitQuery = "limit"
    static let separator = "/"; static let pageLimit = 20
    static let stock = "stock"
}
enum UFitCatalogAction: String { case submit, archive, restore, review }
enum UFitCatalogContractError: LocalizedError {
    case document, page, currencies, draft, stale
    var errorDescription: String? {
        switch self {
        case .document: String(localized: "La fiche reçue est incohérente. Actualisez avant de continuer.")
        case .page: String(localized: "Le catalogue reçu est incohérent. Actualisez pour réessayer.")
        case .currencies: String(localized: "Les devises sont indisponibles. Rechargez-les pour continuer.")
        case .draft: String(localized: "Vérifiez les champs et les photos avant l’enregistrement.")
        case .stale: String(localized: "Cette fiche a changé. Actualisez-la avant de continuer.")
        }
    }
}
struct UFitManagedProduct: Decodable, Identifiable {
    struct Brand: Decodable { let id: String; let brandName: String; let status: UFitProfileStatus }
    struct Product: Decodable {
        let id: String; let brandId: String; let version: Int; let name: String; let description: String; let category: String
        let genderTarget: UFitGenderTarget?; let status: UFitCatalogStatus; let basePrice: Int; let currency: String
        let material: String?; let careInstructions: String?; let rejectionReason: String?
    }
    struct Variant: Decodable {
        let id: String; let productId: String; let size: String?; let color: String?; let sku: String
        let stockQuantity: Int; let priceOverride: Int?; let status: UFitCatalogVariantStatus
    }
    struct Photo: Decodable {
        let id: String; let productId: String; let url: String; let displayUrl: String; let position: Int; let kind: UFitCatalogImageKind
    }
    let product: Product
    let brand: Brand
    let variants: [Variant]
    let images: [Photo]
    var id: String { product.id }
    var revision: UFitCatalogRevision { .init(id: id, version: product.version) }
    func validate(id expectedID: String? = nil, brand expectedBrand: String? = nil) throws {
        guard UUID(uuidString: id) != nil, UUID(uuidString: product.brandId) != nil, product.version > .zero,
              expectedID == nil || expectedID == id, expectedBrand == nil || expectedBrand == product.brandId,
              brand.id == product.brandId, !brand.brandName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              Set(variants.map(\.id)).count == variants.count, Set(images.map(\.id)).count == images.count,
              variants.allSatisfy({ UUID(uuidString: $0.id) != nil && $0.productId == id && (UFitCatalogInput.integerMin...UFitCatalogInput.integerMax).contains($0.stockQuantity) }),
              images.allSatisfy({ UUID(uuidString: $0.id) != nil && $0.productId == id }) else { throw UFitCatalogContractError.document }
    }
}
struct UFitCatalogPage: Decodable { let items: [UFitManagedProduct]; let nextCursor: String? }
struct UFitCatalogWriteRequest: Codable, Equatable {
    struct Variant: Codable, Equatable {
        let id: String?; let expectedStockQuantity: Int?; let size: String?; let color: String?; let sku: String
        let stockQuantity: Int; let priceOverride: Int?; let status: UFitCatalogVariantStatus?
    }
    struct Photo: Codable, Equatable { let id: String?; let url: String; let position: Int; let kind: UFitCatalogImageKind }
    let brandId: String?; let requestId: String?; let expectedVersion: Int?
    let name: String; let description: String; let category: String; let genderTarget: UFitGenderTarget?
    let basePrice: Int; let currency: String; let material: String?; let careInstructions: String?
    let variants: [Variant]; let images: [Photo]
    init(draft: UFitCatalogProductDraft, currency: UFitCatalogCurrency, creatingBrandID: String?, requestID: UUID?, editing: UFitCatalogRevision?) throws {
        guard UFitCatalogDraftValidation.product(draft, currencies: [currency]).isEmpty,
              let price = UFitCatalogInput.minorUnits(draft.price, currency: currency),
              (creatingBrandID != nil && requestID != nil && editing == nil) || (creatingBrandID == nil && requestID == nil && editing != nil) else { throw UFitCatalogContractError.draft }
        brandId = creatingBrandID; requestId = requestID?.uuidString; expectedVersion = editing?.version
        name = UFitCatalogInput.trimmed(draft.name); description = UFitCatalogInput.trimmed(draft.description); category = UFitCatalogInput.trimmed(draft.category)
        genderTarget = draft.gender; basePrice = price; self.currency = currency.code
        func optional(_ value: String) -> String? { let text = UFitCatalogInput.trimmed(value); return text.isEmpty ? nil : text }
        material = optional(draft.material); careInstructions = optional(draft.care)
        variants = try draft.variants.map { value in
            guard let stock = UFitCatalogInput.integer(value.stock) else { throw UFitCatalogContractError.draft }
            let override = optional(value.priceOverride)
            let amount = override.flatMap { UFitCatalogInput.minorUnits($0, currency: currency) }
            guard override == nil || amount != nil, editing == nil || value.serverID == nil || value.expectedStockQuantity != nil else { throw UFitCatalogContractError.draft }
            return Variant(id: editing == nil ? nil : value.serverID, expectedStockQuantity: editing == nil ? nil : value.expectedStockQuantity,
                size: optional(value.size), color: optional(value.color), sku: UFitCatalogInput.trimmed(value.sku), stockQuantity: stock,
                priceOverride: amount, status: editing == nil ? nil : value.status)
        }
        images = try draft.photos.enumerated().map { position, photo in
            guard photo.transfer == .ready, let url = photo.url else { throw UFitCatalogContractError.draft }
            return Photo(id: editing == nil ? nil : photo.serverID, url: url, position: position, kind: photo.kind)
        }
    }
}
extension UFitAPIClient {
    func fetchCatalogCurrencies() async throws -> [UFitCatalogCurrency] {
        struct Metadata: Decodable { let currencies: [UFitCatalogCurrency] }
        let result: Metadata = try await send(UFitCatalogHTTP.get, path: UFitCatalogHTTP.metadata, requiresAuth: true)
        guard !result.currencies.isEmpty, Set(result.currencies.map(\.code)).count == result.currencies.count,
              result.currencies.allSatisfy({ !$0.code.isEmpty && $0.minorUnitDigits >= .zero }) else { throw UFitCatalogContractError.currencies }
        return result.currencies
    }
    func fetchCatalog(brandID: String?, status: UFitCatalogStatus?, cursor: String?) async throws -> UFitCatalogPage {
        var query = [URLQueryItem(name: UFitCatalogHTTP.limitQuery, value: String(UFitCatalogHTTP.pageLimit))]
        if let brandID { query.append(URLQueryItem(name: UFitCatalogHTTP.brandQuery, value: brandID)) }
        if let status { query.append(URLQueryItem(name: UFitCatalogHTTP.statusQuery, value: status.rawValue)) }
        if let cursor { query.append(URLQueryItem(name: UFitCatalogHTTP.cursorQuery, value: cursor)) }
        let page: UFitCatalogPage = try await send(UFitCatalogHTTP.get, path: UFitCatalogHTTP.collection, query: query, requiresAuth: true)
        for item in page.items { try item.validate(brand: brandID) }
        guard Set(page.items.map(\.id)).count == page.items.count,
              page.items.allSatisfy({ status == nil || $0.product.status == status }),
              page.nextCursor == nil || (page.nextCursor == page.items.last?.id && page.nextCursor != cursor && UUID(uuidString: page.nextCursor!) != nil) else { throw UFitCatalogContractError.page }
        return page
    }
    func fetchManagedProduct(id: String, brandID: String?) async throws -> UFitManagedProduct {
        let result: UFitManagedProduct = try await send(UFitCatalogHTTP.get, path: UFitCatalogHTTP.base + id + UFitCatalogHTTP.privateSuffix, requiresAuth: true)
        try result.validate(id: id, brand: brandID); return result
    }
    func recoverCatalogCreation(brandID: String, requestID: String) async throws -> UFitManagedProduct {
        let result: UFitManagedProduct = try await send(UFitCatalogHTTP.get, path: UFitCatalogHTTP.creation + requestID, query: [URLQueryItem(name: UFitCatalogHTTP.brandQuery, value: brandID)], requiresAuth: true)
        try result.validate(brand: brandID); return result
    }
    func writeCatalogProduct(_ request: UFitCatalogWriteRequest, editingID: String?, brandID: String) async throws -> UFitManagedProduct {
        let result: UFitManagedProduct = try await send(editingID == nil ? UFitCatalogHTTP.post : UFitCatalogHTTP.put,
            path: editingID.map { UFitCatalogHTTP.base + $0 } ?? UFitCatalogHTTP.collection, body: request, requiresAuth: true)
        try result.validate(id: editingID, brand: brandID); return result
    }
    func mutateCatalogProduct(_ revision: UFitCatalogRevision, action: UFitCatalogAction, decision: UFitCatalogStatus? = nil, reason: String? = nil) async throws -> UFitManagedProduct {
        struct Body: Encodable { let expectedVersion: Int; let decision: UFitCatalogStatus?; let rejectionReason: String? }
        let result: UFitManagedProduct = try await send(UFitCatalogHTTP.patch, path: UFitCatalogHTTP.base + revision.id + UFitCatalogHTTP.separator + action.rawValue,
            body: Body(expectedVersion: revision.version, decision: decision, rejectionReason: reason), requiresAuth: true)
        try result.validate(id: revision.id); return result
    }
    func updateCatalogStock(_ revision: UFitCatalogRevision, variantID: String, expectedQuantity: Int, quantity: Int) async throws -> UFitManagedProduct {
        struct Body: Encodable { let expectedVersion: Int; let variantId: String; let expectedStockQuantity: Int; let stockQuantity: Int }
        let result: UFitManagedProduct = try await send(UFitCatalogHTTP.patch, path: UFitCatalogHTTP.base + revision.id + UFitCatalogHTTP.separator + UFitCatalogHTTP.stock,
            body: Body(expectedVersion: revision.version, variantId: variantID, expectedStockQuantity: expectedQuantity, stockQuantity: quantity), requiresAuth: true)
        try result.validate(id: revision.id); return result
    }
}
