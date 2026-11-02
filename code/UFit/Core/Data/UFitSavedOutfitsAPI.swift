import Foundation

enum UFitSavedOutfitsHTTP {
    static let get = "GET"; static let put = "PUT"; static let delete = "DELETE"
    static let root = "me/saved-outfits"; static let states = "me/saved-outfits/states"; static let separator = "/"
    static let limit = "limit"; static let cursor = "cursor"; static let identities = "ids"; static let identitySeparator = ","
    static let pageLimit = 20; static let maximumIdentities = 50
    static let savedTimePattern = #"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{6}Z$"#
    static let cursorPattern = #"^[A-Za-z0-9_-]+$"#; static let maximumCursorLength = 256
}
enum UFitSavedOutfitContractError: LocalizedError {
    case page, state
    var errorDescription: String? {
        switch self {
        case .page: String(localized: "La liste des favoris n’a pas pu être confirmée. Actualisez-la.")
        case .state: String(localized: "L’état du favori n’a pas pu être confirmé. Vérifiez-le avant de continuer.")
        }
    }
}
struct UFitSavedReferencesDTO: Decodable {
    struct Item: Decodable { let id: String; let savedAt: String }
    let items: [Item]
    @UFitRequiredNullable var nextCursor: String?
}
struct UFitSavedStatesDTO: Decodable {
    struct Item: Decodable { let id: String; let saved: Bool }
    let items: [Item]
}
struct UFitSavedActionDTO: Decodable { let saved: Bool }

extension UFitAPIClient {
    func fetchSavedOutfits(cursor: String? = nil) async throws -> UFitSavedReferencesDTO {
        var query = [URLQueryItem(name: UFitSavedOutfitsHTTP.limit, value: String(UFitSavedOutfitsHTTP.pageLimit))]
        if let cursor { query.append(.init(name: UFitSavedOutfitsHTTP.cursor, value: cursor)) }
        do {
            let page: UFitSavedReferencesDTO = try await send(UFitSavedOutfitsHTTP.get, path: UFitSavedOutfitsHTTP.root,
                query: query, requiresAuth: true, cachePolicy: .reloadIgnoringLocalCacheData)
            guard page.items.count <= UFitSavedOutfitsHTTP.pageLimit, Set(page.items.map(\.id)).count == page.items.count,
                  page.items.allSatisfy({ UUID(uuidString: $0.id) != nil &&
                      $0.savedAt.range(of: UFitSavedOutfitsHTTP.savedTimePattern, options: .regularExpression) != nil && UFitTimestamp(isoString: $0.savedAt) != nil }),
                  page.nextCursor == nil || (!page.items.isEmpty && page.nextCursor != cursor &&
                      page.nextCursor!.count <= UFitSavedOutfitsHTTP.maximumCursorLength &&
                      page.nextCursor!.range(of: UFitSavedOutfitsHTTP.cursorPattern, options: .regularExpression) != nil) else { throw UFitSavedOutfitContractError.page }
            let sorted = page.items.sorted { left, right in left.savedAt == right.savedAt ? left.id > right.id : left.savedAt > right.savedAt }
            guard sorted.map(\.id) == page.items.map(\.id) else { throw UFitSavedOutfitContractError.page }
            return page
        } catch is DecodingError { throw UFitSavedOutfitContractError.page }
    }
    func fetchSavedOutfitStates(ids: [String]) async throws -> [UFitSavedStatesDTO.Item] {
        guard !ids.isEmpty, ids.count <= UFitSavedOutfitsHTTP.maximumIdentities, Set(ids).count == ids.count,
              ids.allSatisfy({ UUID(uuidString: $0) != nil }) else { throw UFitSavedOutfitContractError.state }
        do {
            let response: UFitSavedStatesDTO = try await send(UFitSavedOutfitsHTTP.get, path: UFitSavedOutfitsHTTP.states,
                query: [.init(name: UFitSavedOutfitsHTTP.identities, value: ids.joined(separator: UFitSavedOutfitsHTTP.identitySeparator))],
                requiresAuth: true, cachePolicy: .reloadIgnoringLocalCacheData)
            guard response.items.map(\.id) == ids else { throw UFitSavedOutfitContractError.state }
            return response.items
        } catch is DecodingError { throw UFitSavedOutfitContractError.state }
    }
    func setSavedOutfit(id: String, saved: Bool) async throws {
        guard UUID(uuidString: id) != nil else { throw UFitSavedOutfitContractError.state }
        do {
            let result: UFitSavedActionDTO = try await send(saved ? UFitSavedOutfitsHTTP.put : UFitSavedOutfitsHTTP.delete,
                path: UFitSavedOutfitsHTTP.root + UFitSavedOutfitsHTTP.separator + id, requiresAuth: true)
            guard result.saved == saved else { throw UFitSavedOutfitContractError.state }
        } catch is DecodingError { throw UFitSavedOutfitContractError.state }
    }
}
