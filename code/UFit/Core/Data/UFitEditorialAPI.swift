import Foundation

enum UFitEditorialHTTP {
    static let get = "GET"; static let root = "editorial/collections"; static let slash = "/"; static let items = "/items"
    static let limit = "limit"; static let cursor = "cursor"; static let version = "version"
    static let pageSize = 20; static let maximumItems = 100; static let maximumVersion = 2_147_483_646
    static let titleMinimum = 2; static let titleMaximum = 120; static let subtitleMaximum = 240; static let descriptionMaximum = 6_000
    static let cursorMaximum = 512; static let step = 1
    static let missing = 404; static let changed = 409
    static let protocols = ["http", "https"]
}
enum UFitEditorialKind: String, Codable, Hashable { case outfit, product }
struct UFitEditorialCollection: Decodable, Identifiable {
    let id: String
    let version: Int
    let title: String
    @UFitRequiredNullable var subtitle: String?
    let description: String
    @UFitRequiredNullable var coverImageUrl: String?
    let itemCount: Int
    func validate() throws {
        guard editorialUUID(id), (UFitEditorialHTTP.step...UFitEditorialHTTP.maximumVersion).contains(version),
              (UFitEditorialHTTP.titleMinimum...UFitEditorialHTTP.titleMaximum).contains(title.utf16.count), title == title.trimmingCharacters(in: .whitespacesAndNewlines),
              !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, description.utf16.count <= UFitEditorialHTTP.descriptionMaximum,
              subtitle == nil || (!subtitle!.isEmpty && subtitle!.utf16.count <= UFitEditorialHTTP.subtitleMaximum),
              (UFitEditorialHTTP.step...UFitEditorialHTTP.maximumItems).contains(itemCount),
              coverImageUrl == nil || editorialImageURL(coverImageUrl!) else { throw UFitEditorialFailure.contract }
    }
}
struct UFitEditorialEntry: Decodable, Identifiable {
    let id: String
    let itemType: UFitEditorialKind
    let contentId: String
    let position: Int
    let title: String
    @UFitRequiredNullable var imageUrl: String?
    func validate() throws {
        guard editorialUUID(id), editorialUUID(contentId), (.zero..<UFitEditorialHTTP.maximumItems).contains(position),
              !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              imageUrl == nil || editorialImageURL(imageUrl!) else { throw UFitEditorialFailure.contract }
    }
}
struct UFitEditorialPage: Decodable {
    let items: [UFitEditorialCollection]
    @UFitRequiredNullable var nextCursor: String?
    func validate(cursor: String?) throws {
        try items.forEach { try $0.validate() }
        guard items.count <= UFitEditorialHTTP.pageSize, Set(items.map(\.id)).count == items.count else { throw UFitEditorialFailure.contract }
        try validateEditorialCursor(nextCursor, previous: cursor, isEmpty: items.isEmpty)
    }
}
struct UFitEditorialItemsPage: Decodable {
    let items: [UFitEditorialEntry]
    @UFitRequiredNullable var nextCursor: String?
    func validate(cursor: String?) throws {
        try items.forEach { try $0.validate() }
        guard items.count <= UFitEditorialHTTP.pageSize, Set(items.map(\.id)).count == items.count,
              Set(items.map { EditorialIdentity(kind: $0.itemType, id: $0.contentId) }).count == items.count,
              zip(items, items.dropFirst()).allSatisfy({ $0.0.position < $0.1.position }) else { throw UFitEditorialFailure.contract }
        try validateEditorialCursor(nextCursor, previous: cursor, isEmpty: items.isEmpty)
    }
}
private struct EditorialIdentity: Hashable { let kind: UFitEditorialKind; let id: String }
enum UFitEditorialFailure: LocalizedError {
    case contract
    var errorDescription: String? { UFitEditorialCopy.loadFailed }
    static func status(_ error: Error) -> Int? {
        if case .requestFailed(let status, _, _) = error as? UFitAPIError { return status }
        return nil
    }
}
func editorialUUID(_ raw: String) -> Bool { UUID(uuidString: raw)?.uuidString.lowercased() == raw }
func editorialImageURL(_ raw: String) -> Bool {
    guard let url = URL(string: raw), let scheme = url.scheme, UFitEditorialHTTP.protocols.contains(scheme),
          url.host != nil, url.user == nil, url.password == nil else { return false }
    return true
}
private func validateEditorialCursor(_ cursor: String?, previous: String?, isEmpty: Bool) throws {
    guard let cursor else { return }
    guard !isEmpty, !cursor.isEmpty, cursor.utf8.count <= UFitEditorialHTTP.cursorMaximum, cursor != previous else { throw UFitEditorialFailure.contract }
}
extension UFitAPIClient {
    func fetchEditorialCollections(cursor: String? = nil) async throws -> UFitEditorialPage {
        var query = [URLQueryItem(name: UFitEditorialHTTP.limit, value: String(UFitEditorialHTTP.pageSize))]
        if let cursor { query.append(URLQueryItem(name: UFitEditorialHTTP.cursor, value: cursor)) }
        let page: UFitEditorialPage = try await send(UFitEditorialHTTP.get, path: UFitEditorialHTTP.root, query: query, cachePolicy: .reloadIgnoringLocalCacheData)
        try page.validate(cursor: cursor)
        return page
    }
    func fetchEditorialCollection(id: String) async throws -> UFitEditorialCollection {
        let collection: UFitEditorialCollection = try await send(UFitEditorialHTTP.get, path: UFitEditorialHTTP.root + UFitEditorialHTTP.slash + id,
            cachePolicy: .reloadIgnoringLocalCacheData)
        try collection.validate()
        guard collection.id == id else { throw UFitEditorialFailure.contract }
        return collection
    }
    func fetchEditorialItems(id: String, version: Int, cursor: String? = nil) async throws -> UFitEditorialItemsPage {
        var query = [URLQueryItem(name: UFitEditorialHTTP.limit, value: String(UFitEditorialHTTP.pageSize)), URLQueryItem(name: UFitEditorialHTTP.version, value: String(version))]
        if let cursor { query.append(URLQueryItem(name: UFitEditorialHTTP.cursor, value: cursor)) }
        let page: UFitEditorialItemsPage = try await send(UFitEditorialHTTP.get,
            path: UFitEditorialHTTP.root + UFitEditorialHTTP.slash + id + UFitEditorialHTTP.items, query: query, cachePolicy: .reloadIgnoringLocalCacheData)
        try page.validate(cursor: cursor)
        return page
    }
}
