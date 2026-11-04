import Foundation

struct UFitBrandOutfitIntegrationPiece: Decodable, Identifiable {
    let itemId: String
    let productId: String
    let name: String
    let productStatus: UFitCatalogStatus
    var id: String { itemId }
}

struct UFitBrandOutfitIntegration: Decodable, Identifiable {
    let outfit: UFitOutfitCardDTO
    let pieces: [UFitBrandOutfitIntegrationPiece]
    var id: String { outfit.id }
}

struct UFitBrandOutfitIntegrationsPage: Decodable {
    let brandId: String
    let items: [UFitBrandOutfitIntegration]
    @UFitRequiredNullable var nextCursor: String?
}

enum UFitBrandOutfitIntegrationFailure: LocalizedError {
    case invalid
    var errorDescription: String? { String(localized: "Les tenues reçues ne correspondent pas à cet espace. Actualisez la page.") }
}

private enum BrandIntegrationHTTP {
    static let get = "GET"
    static let path = "outfits/brand-integrations"
    static let brand = "brandId"
    static let cursor = "cursor"
    static let limit = "limit"
    static let pageSize = 20
}

extension UFitAPIClient {
    func fetchBrandOutfitIntegrations(brandID: String, cursor: String?) async throws -> UFitBrandOutfitIntegrationsPage {
        var query = [URLQueryItem(name: BrandIntegrationHTTP.brand, value: brandID),
                     URLQueryItem(name: BrandIntegrationHTTP.limit, value: String(BrandIntegrationHTTP.pageSize))]
        if let cursor { query.append(URLQueryItem(name: BrandIntegrationHTTP.cursor, value: cursor)) }
        let page: UFitBrandOutfitIntegrationsPage
        do { page = try await send(BrandIntegrationHTTP.get, path: BrandIntegrationHTTP.path, query: query, requiresAuth: true) }
        catch is DecodingError { throw UFitBrandOutfitIntegrationFailure.invalid }
        guard page.brandId == brandID, page.items.count <= BrandIntegrationHTTP.pageSize,
              Set(page.items.map(\.id)).count == page.items.count,
              page.nextCursor == nil || (page.nextCursor == page.items.last?.id && page.nextCursor != cursor && UUID(uuidString: page.nextCursor!) != nil) else {
            throw UFitBrandOutfitIntegrationFailure.invalid
        }
        for entry in page.items {
            try entry.outfit.validateShopping()
            try UFitPublicOutfitIdentity.validate(id: entry.id, author: entry.outfit.author,
                creatorID: entry.outfit.creatorId, brandID: entry.outfit.brandId)
            let items = Dictionary(uniqueKeysWithValues: entry.outfit.items.map { ($0.id, $0) })
            guard !entry.pieces.isEmpty, Set(entry.pieces.map(\.id)).count == entry.pieces.count,
                  Set(entry.pieces.map(\.productId)).count == entry.pieces.count else { throw UFitBrandOutfitIntegrationFailure.invalid }
            for piece in entry.pieces {
                guard UUID(uuidString: piece.itemId) != nil, UUID(uuidString: piece.productId) != nil,
                      !piece.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                      let item = items[piece.itemId], item.isShoppable else { throw UFitBrandOutfitIntegrationFailure.invalid }
                if let product = item.product {
                    guard product.id == piece.productId, product.brandId == brandID, product.name == piece.name,
                          piece.productStatus == .active else { throw UFitBrandOutfitIntegrationFailure.invalid }
                }
            }
        }
        return page
    }
}
