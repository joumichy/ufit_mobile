import Foundation

enum UFitOutfitEditingHTTP {
    static let get = "GET"; static let post = "POST"; static let put = "PUT"; static let patch = "PATCH"
    static let collection = "outfits"; static let base = "outfits/"; static let managed = "outfits/managed"; static let metadata = "outfits/metadata"
    static let creation = "outfits/creation-requests/"; static let privateSuffix = "/private"; static let separator = "/"
    static let creator = "creatorId"; static let brand = "brandId"; static let status = "status"; static let cursor = "cursor"; static let limit = "limit"
    static let pageLimit = 20
    static func ownerQuery(_ scope: UFitOutfitScope) -> URLQueryItem { .init(name: scope.kind == .creator ? creator : brand, value: scope.profileID) }
}
enum UFitOutfitAction: String { case publish, withdraw, archive, restore }
enum UFitOutfitContractError: LocalizedError {
    case document, page, metadata, draft
    var errorDescription: String? {
        switch self {
        case .document: String(localized: "La tenue reçue est incohérente. Actualisez avant de continuer.")
        case .page: String(localized: "La liste reçue est incohérente. Actualisez les tenues.")
        case .metadata: String(localized: "Les styles sont indisponibles. Rechargez-les avant de continuer.")
        case .draft: String(localized: "Vérifiez les champs, les pièces et les photos avant l’enregistrement.")
        }
    }
}
struct UFitManagedOutfit: Decodable, Identifiable {
    struct Owner: Decodable { let id: String; let kind: OutfitAuthor.Kind; let name: String; let status: UFitProfileStatus }
    struct Photo: Decodable { let id: String; let url: String; let displayUrl: String; let position: Int }
    struct Piece: Decodable {
        let id: String; let itemType: UFitOutfitItemType; let label: String; let position: Int; let isRequired: Bool; let isShoppable: Bool
        @UFitRequiredNullable var productId: String?
        @UFitRequiredNullable var externalLabel: String?
        @UFitRequiredNullable var stylingNote: String?
        @UFitRequiredNullable var product: UFitOutfitProductDTO?
    }
    let id: String; let version: Int; let title: String; let description: String; let coverImageUrl: String
    let status: UFitOutfitStatus; let visibility: UFitOutfitVisibility
    let pins: [UFitOutfitPin]
    let images: [Photo]; let items: [Piece]; let tags: [UFitOutfitTag]; let prices: [UFitProductPriceDTO]
    @UFitRequiredNullable var creatorId: String?
    @UFitRequiredNullable var brandId: String?
    @UFitRequiredNullable var author: OutfitAuthor?
    @UFitRequiredNullable var owner: Owner?
    @UFitRequiredNullable var genderTarget: UFitGenderTarget?
    @UFitRequiredNullable var publishedAt: String?
    @UFitRequiredNullable var scheduledFor: String?
    @UFitRequiredNullable var publicationTimeZone: String?
    let createdAt: String; let updatedAt: String
    var revision: UFitOutfitRevision { .init(id: id, version: version) }
    var scope: UFitOutfitScope? { owner.map { .init(profileID: $0.id, kind: $0.kind) } }
    func validate(id expectedID: String? = nil, scope expectedScope: UFitOutfitScope? = nil) throws {
        func uuid(_ value: String) -> Bool { UUID(uuidString: value) != nil }
        func unique<T: Hashable>(_ values: [T]) -> Bool { Set(values).count == values.count }
        guard (scheduledFor == nil) == (publicationTimeZone == nil),
              scheduledFor == nil || (UFitPublicationDate.parse(scheduledFor!) != nil && TimeZone(identifier: publicationTimeZone!) != nil),
              status != .scheduled || (scheduledFor != nil && visibility == .private && publishedAt == nil),
              uuid(id), version >= UFitOutfitInput.versionInitial, expectedID == nil || expectedID == id,
              expectedScope == nil || expectedScope == scope, !(creatorId != nil && brandId != nil),
              creatorId == nil || uuid(creatorId!), brandId == nil || uuid(brandId!),
              owner == nil ? (creatorId == nil && brandId == nil) : (owner!.id == (owner!.kind == .creator ? creatorId : brandId)),
              author == nil || (author?.id == owner?.id && author?.kind == owner?.kind),
              UFitOutfitPin.valid(pins, imageIDs: Set(images.map(\.id)), itemIDs: Set(items.map(\.id))),
              unique(items.map(\.id)), unique(items.map(\.position)), unique(images.map(\.id)), unique(images.map(\.position)), unique(tags.map(\.id)),
              images.count <= UFitOutfitInput.photosMax, items.count <= UFitOutfitInput.itemsMax, tags.count <= UFitOutfitInput.tagsMax,
              images.allSatisfy({ uuid($0.id) && $0.position >= .zero && validImageURL($0.url) && validImageURL($0.displayUrl) }),
              coverImageUrl == (images.sorted(by: { $0.position < $1.position }).first?.url ?? String()),
              items.allSatisfy({ item in
                  guard uuid(item.id), item.position >= .zero else { return false }
                  if item.isShoppable { return item.productId.map(uuid) == true && item.externalLabel == nil && (item.product == nil || item.product?.id == item.productId) }
                  return item.productId == nil && item.product == nil && item.externalLabel?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
              }), unique(items.compactMap(\.productId)), tags.allSatisfy({ uuid($0.id) && !$0.label.isEmpty && !$0.slug.isEmpty }),
              unique(prices.map(\.currency)), prices.allSatisfy({ $0.min >= .zero && $0.max >= $0.min && !$0.currency.isEmpty }) else { throw UFitOutfitContractError.document }
    }
    private func validImageURL(_ text: String) -> Bool {
        guard let url = URL(string: text), let scheme = url.scheme else { return false }
        return UFitMultipartEncoding.allowedSchemes.contains(scheme) && url.host != nil && url.user == nil && url.password == nil
    }
}
struct UFitManagedOutfitPage: Decodable { let items: [UFitManagedOutfit]; let nextCursor: String? }
struct UFitOutfitMetadata: Codable {
    let tags: [UFitOutfitTag]; let itemTypes: [UFitOutfitItemType]; let tagTypes: [UFitOutfitTagType]; let statuses: [UFitOutfitStatus]
    func validate() throws {
        guard Set(tags.map(\.id)).count == tags.count, tags.allSatisfy({ UUID(uuidString: $0.id) != nil && !$0.slug.isEmpty && !$0.label.isEmpty }),
              Set(itemTypes) == Set(UFitOutfitItemType.allCases), itemTypes.count == UFitOutfitItemType.allCases.count,
              Set(tagTypes) == Set(UFitOutfitTagType.allCases), tagTypes.count == UFitOutfitTagType.allCases.count,
              Set(statuses) == Set(UFitOutfitStatus.allCases), statuses.count == UFitOutfitStatus.allCases.count else { throw UFitOutfitContractError.metadata }
    }
}
extension UFitAPIClient {
    func fetchOutfitMetadata() async throws -> UFitOutfitMetadata {
        let result: UFitOutfitMetadata = try await send(UFitOutfitEditingHTTP.get, path: UFitOutfitEditingHTTP.metadata, requiresAuth: true)
        try result.validate(); return result
    }
    func fetchManagedOutfits(scope: UFitOutfitScope?, status: UFitOutfitStatus?, cursor: String?) async throws -> UFitManagedOutfitPage {
        var query = [URLQueryItem(name: UFitOutfitEditingHTTP.limit, value: String(UFitOutfitEditingHTTP.pageLimit))]
        if let scope { query.append(UFitOutfitEditingHTTP.ownerQuery(scope)) }
        if let status { query.append(.init(name: UFitOutfitEditingHTTP.status, value: status.rawValue)) }
        if let cursor { query.append(.init(name: UFitOutfitEditingHTTP.cursor, value: cursor)) }
        let page: UFitManagedOutfitPage = try await send(UFitOutfitEditingHTTP.get, path: UFitOutfitEditingHTTP.managed, query: query, requiresAuth: true)
        for item in page.items { try item.validate(scope: scope) }
        guard Set(page.items.map(\.id)).count == page.items.count, page.items.allSatisfy({ status == nil || $0.status == status }),
              page.nextCursor == nil || (page.nextCursor == page.items.last?.id && page.nextCursor != cursor && UUID(uuidString: page.nextCursor!) != nil) else { throw UFitOutfitContractError.page }
        return page
    }
    func fetchManagedOutfit(id: String, scope: UFitOutfitScope?) async throws -> UFitManagedOutfit {
        let result: UFitManagedOutfit = try await send(UFitOutfitEditingHTTP.get, path: UFitOutfitEditingHTTP.base + id + UFitOutfitEditingHTTP.privateSuffix, requiresAuth: true)
        try result.validate(id: id, scope: scope); return result
    }
    func recoverOutfitCreation(scope: UFitOutfitScope, requestID: String) async throws -> UFitManagedOutfit {
        let result: UFitManagedOutfit = try await send(UFitOutfitEditingHTTP.get, path: UFitOutfitEditingHTTP.creation + requestID,
            query: [UFitOutfitEditingHTTP.ownerQuery(scope)], requiresAuth: true)
        try result.validate(scope: scope); return result
    }
    func writeOutfit(_ request: UFitOutfitWriteRequest, editingID: String?, scope: UFitOutfitScope) async throws -> UFitManagedOutfit {
        let result: UFitManagedOutfit = try await send(editingID == nil ? UFitOutfitEditingHTTP.post : UFitOutfitEditingHTTP.put,
            path: editingID.map { UFitOutfitEditingHTTP.base + $0 } ?? UFitOutfitEditingHTTP.collection, body: request, requiresAuth: true)
        try result.validate(id: editingID, scope: scope); return result
    }
    func mutateOutfit(_ revision: UFitOutfitRevision, action: UFitOutfitAction) async throws -> UFitManagedOutfit {
        struct Body: Encodable { let expectedVersion: Int }
        let result: UFitManagedOutfit = try await send(UFitOutfitEditingHTTP.patch, path: UFitOutfitEditingHTTP.base + revision.id + UFitOutfitEditingHTTP.separator + action.rawValue,
            body: Body(expectedVersion: revision.version), requiresAuth: true)
        try result.validate(id: revision.id); return result
    }
}
