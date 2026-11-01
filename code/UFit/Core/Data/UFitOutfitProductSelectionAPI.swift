import Foundation

enum UFitOutfitSelectionHTTP {
    static let collection = "products/selection"; static let search = "search"; static let searchMax = 120
}
struct UFitOutfitSelectableProduct: Decodable, Identifiable {
    let product: UFitPublicProductDTO
    let brandName: String
    var id: String { product.id }
    private enum CodingKeys: String, CodingKey { case brandName }
    init(from decoder: Decoder) throws {
        product = try UFitPublicProductDTO(from: decoder)
        brandName = try decoder.container(keyedBy: CodingKeys.self).decode(String.self, forKey: .brandName)
    }
    func validate() throws {
        guard UUID(uuidString: id) != nil, UUID(uuidString: product.brandId) != nil, !product.name.isEmpty, !brandName.isEmpty,
              product.price.min >= .zero, product.price.max >= product.price.min, !product.price.currency.isEmpty,
              Set(product.variants.map(\.id)).count == product.variants.count,
              product.variants.allSatisfy({ UUID(uuidString: $0.id) != nil && $0.stockQuantity >= .zero && $0.price >= .zero }) else { throw UFitOutfitContractError.page }
    }
    func choice() -> UFitOutfitProductChoice {
        .init(id: id, name: product.name, brandName: brandName,
            image: product.images.sorted { $0.position < $1.position }.first?.url,
            price: UFitMoney.ranges([product.price]))
    }
}
struct UFitOutfitProductSelectionPage: Decodable { let items: [UFitOutfitSelectableProduct]; let nextCursor: String? }
extension UFitAPIClient {
    func fetchOutfitProductSelection(search: String, cursor: String?) async throws -> UFitOutfitProductSelectionPage {
        let search = UFitOutfitInput.trimmed(search)
        guard search.unicodeScalars.count <= UFitOutfitSelectionHTTP.searchMax else { throw UFitOutfitContractError.page }
        var query = [URLQueryItem(name: UFitOutfitEditingHTTP.limit, value: String(UFitOutfitEditingHTTP.pageLimit))]
        if !search.isEmpty { query.append(.init(name: UFitOutfitSelectionHTTP.search, value: search)) }
        if let cursor { query.append(.init(name: UFitOutfitEditingHTTP.cursor, value: cursor)) }
        let page: UFitOutfitProductSelectionPage = try await send(UFitOutfitEditingHTTP.get, path: UFitOutfitSelectionHTTP.collection, query: query, requiresAuth: true)
        for item in page.items { try item.validate() }
        guard Set(page.items.map(\.id)).count == page.items.count,
              page.nextCursor == nil || (page.nextCursor == page.items.last?.id && page.nextCursor != cursor && UUID(uuidString: page.nextCursor!) != nil) else { throw UFitOutfitContractError.page }
        return page
    }
}
