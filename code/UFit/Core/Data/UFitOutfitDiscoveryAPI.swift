import Foundation

enum UFitOutfitSearchScope: String, CaseIterable {
    case all, creators, pieces
    var title: String {
        switch self {
        case .all: String(localized: "Tout")
        case .creators: String(localized: "Créateurs")
        case .pieces: String(localized: "Pièces")
        }
    }
}
struct UFitOutfitSearchCriteria: Equatable, Hashable {
    var query = String()
    var scope = UFitOutfitSearchScope.all
    var styleID: String?
    var occasionID: String?
    var itemType: UFitOutfitItemType?
    var hasFilters: Bool { styleID != nil || occasionID != nil || itemType != nil }
    var isRefined: Bool { hasFilters || !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    var queryItems: [URLQueryItem] {
        var items = [URLQueryItem(name: UFitOutfitDiscoveryHTTP.scope, value: scope.rawValue)]
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.isEmpty { items.append(.init(name: UFitOutfitDiscoveryHTTP.query, value: text)) }
        if let styleID { items.append(.init(name: UFitOutfitDiscoveryHTTP.style, value: styleID)) }
        if let occasionID { items.append(.init(name: UFitOutfitDiscoveryHTTP.occasion, value: occasionID)) }
        if let itemType { items.append(.init(name: UFitOutfitDiscoveryHTTP.itemType, value: itemType.rawValue)) }
        return items
    }
}
enum UFitOutfitDiscoveryHTTP {
    static let get = "GET", options = "outfits/discovery", query = "q", scope = "scope"
    static let style = "styleId", occasion = "occasionId", itemType = "itemType"
    static let queryMax = 120, debounceMilliseconds = 350
    static let separator = " · "
}
struct UFitOutfitDiscoveryOptions: Decodable {
    let tags: [UFitOutfitTag]
    let itemTypes: [UFitOutfitItemType]
    func validate() throws {
        guard Set(tags.map(\.id)).count == tags.count,
              Set(tags.map { $0.type.rawValue + UFitOutfitDiscoveryHTTP.separator + $0.slug }).count == tags.count,
              tags.allSatisfy({ UUID(uuidString: $0.id) != nil && !$0.label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !$0.slug.isEmpty
                  && ($0.type == .style || $0.type == .occasion) }),
              Set(itemTypes) == Set(UFitOutfitItemType.allCases), itemTypes.count == UFitOutfitItemType.allCases.count else {
            throw UFitPublicProfileContractError.outfits
        }
    }
}
extension UFitAPIClient {
    func fetchOutfitDiscoveryOptions() async throws -> UFitOutfitDiscoveryOptions {
        do {
            let options: UFitOutfitDiscoveryOptions = try await send(UFitOutfitDiscoveryHTTP.get, path: UFitOutfitDiscoveryHTTP.options)
            try options.validate()
            return options
        } catch is DecodingError { throw UFitPublicProfileContractError.outfits }
    }
}
