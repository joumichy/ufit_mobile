import Foundation

enum UFitNotificationDestination: Equatable, Decodable {
    case creatorApplication(String), brandApplication(String), customerOrder(String), brandOrder(String, brandID: String)
    case customerReturn(String, orderID: String), brandReturn(String, brandID: String)
    private enum Kind: String, Decodable { case creatorApplication = "creator_application", brandApplication = "brand_application", customerOrder = "customer_order", brandOrder = "brand_order", customerReturn = "customer_return", brandReturn = "brand_return" }
    private enum CodingKeys: String, CodingKey { case kind, id, brandId, orderId }
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(Kind.self, forKey: .kind)
        func identifier(_ key: CodingKeys) throws -> String {
            let value = try container.decode(String.self, forKey: key)
            guard let id = UUID(uuidString: value), id.uuidString.lowercased() == value else { throw UFitNotificationError.document }
            return value
        }
        let id = try identifier(.id)
        let needsBrand = kind == .brandOrder || kind == .brandReturn
        guard container.contains(.brandId) == needsBrand, container.contains(.orderId) == (kind == .customerReturn) else { throw UFitNotificationError.document }
        switch kind {
        case .creatorApplication: self = .creatorApplication(id)
        case .brandApplication: self = .brandApplication(id)
        case .customerOrder: self = .customerOrder(id)
        case .brandOrder: self = .brandOrder(id, brandID: try identifier(.brandId))
        case .customerReturn: self = .customerReturn(id, orderID: try identifier(.orderId))
        case .brandReturn: self = .brandReturn(id, brandID: try identifier(.brandId))
        }
    }
    var brandID: String? { switch self { case .brandOrder(_, let id), .brandReturn(_, let id): id; default: nil } }
}
struct UFitNotificationDetail: Decodable {
    let id: String
    let subject: String
    let text: String
    let createdAt: UFitTimestamp
    let destination: UFitNotificationDestination
}
enum UFitNotificationOpeningPhase: Equatable { case waiting, signIn, loading, unavailable, failed(String), ready }
enum UFitNotificationLink {
    static let scheme = "ufit", host = "notifications"
    private static let separator = "/", componentCount = 1, authoritySeparator = "://"
    static func url(identifier: String) -> URL? {
        guard UUID(uuidString: identifier)?.uuidString.lowercased() == identifier else { return nil }
        return URL(string: scheme + authoritySeparator + host + separator + identifier)
    }
    static func recognizes(_ url: URL) -> Bool { url.scheme == scheme && url.host == host }
    static func identifier(_ url: URL) -> String? {
        guard recognizes(url), url.user == nil, url.password == nil, url.port == nil, url.query == nil, url.fragment == nil else { return nil }
        let components = url.path.split(separator: Character(separator))
        guard components.count == componentCount, let component = components.first, let id = UUID(uuidString: String(component)),
              url.path == separator + String(component) else { return nil }
        return id.uuidString.lowercased()
    }
}
enum UFitNotificationError: LocalizedError {
    case document, workspace
    var errorDescription: String? {
        switch self {
        case .document: String(localized: "Cette notification est indisponible. Fermez-la et réessayez depuis le message d’origine.")
        case .workspace: String(localized: "Votre espace marque est indisponible. Réessayez pour actualiser vos accès.")
        }
    }
}
