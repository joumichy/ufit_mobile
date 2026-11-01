import Foundation

private enum PublicProfileHTTP {
    static let get = "GET"; static let put = "PUT"; static let delete = "DELETE"
    static let creators = "public/creators/"; static let follows = "me/creator-follows/"
    static let schemes = ["https", "http"]; static let separator = " · "
}
enum UFitPublicProfileContractError: LocalizedError {
    case profile, outfits, relationship
    var errorDescription: String? {
        switch self {
        case .profile: String(localized: "Le profil reçu est incohérent. Actualisez avant de continuer.")
        case .outfits: String(localized: "Les tenues reçues sont incohérentes. Actualisez pour réessayer.")
        case .relationship: String(localized: "Le suivi n’a pas pu être confirmé. Actualisez son état.")
        }
    }
}
struct UFitPublicCreatorDTO: Decodable {
    struct Grade: Decodable { let code: String; let label: String }
    struct Stats: Decodable { let followers: Int; let publishedOutfits: Int }
    let id: String; let displayName: String; let slug: String; let bio: String?; let avatarUrl: String?
    let grade: Grade; let stats: Stats; let socialAccounts: [UFitCreatorSocialAccount]
}
struct UFitCreatorFollowDTO: Decodable { let following: Bool }

private func publicProfileURL(_ raw: String?) throws -> URL? {
    guard let raw else { return nil }
    guard let url = URL(string: raw), let scheme = url.scheme, PublicProfileHTTP.schemes.contains(scheme),
          url.host != nil, url.user == nil, url.password == nil else { throw UFitPublicProfileContractError.profile }
    return url
}
extension UFitAPIClient {
    func fetchPublicProfile(_ reference: UFitPublicProfileReference) async throws -> UFitPublicProfilePresentation {
        guard UUID(uuidString: reference.id) != nil else { throw UFitPublicProfileContractError.profile }
        do {
            switch reference.kind {
            case .creator:
                let value: UFitPublicCreatorDTO = try await send(PublicProfileHTTP.get, path: PublicProfileHTTP.creators + reference.id)
                guard value.id == reference.id, !value.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !value.slug.isEmpty,
                      !value.grade.code.isEmpty, !value.grade.label.isEmpty, value.stats.followers >= .zero, value.stats.publishedOutfits >= .zero,
                      Set(value.socialAccounts.map(\.platform)).count == value.socialAccounts.count else { throw UFitPublicProfileContractError.profile }
                _ = try publicProfileURL(value.avatarUrl)
                let links = try value.socialAccounts.map { account in
                    guard !account.handle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw UFitPublicProfileContractError.profile }
                    return UFitPublicProfileLink(id: account.platform.rawValue, label: account.platform.label + PublicProfileHTTP.separator + account.handle,
                        destination: try publicProfileURL(account.url))
                }
                return .init(reference: reference, name: value.displayName, slug: value.slug, bio: value.bio, avatarURL: value.avatarUrl, grade: value.grade.label,
                    stats: [.init(id: .followers, value: value.stats.followers), .init(id: .outfits, value: value.stats.publishedOutfits)], links: links)
            case .brand:
                let value = try await fetchPublicBrand(id: reference.id)
                guard value.id == reference.id, !value.brandName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !value.slug.isEmpty,
                      value.stats.publishedOutfits >= .zero, value.stats.activeProducts >= .zero else { throw UFitPublicProfileContractError.profile }
                let website = try publicProfileURL(value.websiteUrl)
                let links = website.map { [UFitPublicProfileLink(id: PublicProfileLinkKind.website, label: PublicProfileLinkKind.label, destination: $0)] } ?? []
                return .init(reference: reference, name: value.brandName, slug: value.slug, bio: value.bio, avatarURL: nil, grade: nil,
                    stats: [.init(id: .outfits, value: value.stats.publishedOutfits), .init(id: .products, value: value.stats.activeProducts)], links: links)
            }
        } catch is DecodingError { throw UFitPublicProfileContractError.profile }
    }
    func fetchCreatorFollow(id: String) async throws -> Bool {
        guard UUID(uuidString: id) != nil else { throw UFitPublicProfileContractError.relationship }
        do {
            let value: UFitCreatorFollowDTO = try await send(PublicProfileHTTP.get, path: PublicProfileHTTP.follows + id, requiresAuth: true)
            return value.following
        } catch is DecodingError { throw UFitPublicProfileContractError.relationship }
    }
    func setCreatorFollow(id: String, following: Bool) async throws -> Bool {
        guard UUID(uuidString: id) != nil else { throw UFitPublicProfileContractError.relationship }
        do {
            let value: UFitCreatorFollowDTO = try await send(following ? PublicProfileHTTP.put : PublicProfileHTTP.delete, path: PublicProfileHTTP.follows + id, requiresAuth: true)
            guard value.following == following else { throw UFitPublicProfileContractError.relationship }
            return value.following
        } catch is DecodingError { throw UFitPublicProfileContractError.relationship }
    }
}
private enum PublicProfileLinkKind { static let website = "website"; static let label = String(localized: "Site de la marque") }

enum UFitPublicOutfitIdentity {
    static func validate(id: String, author: OutfitAuthor?, creatorID: String?, brandID: String?) throws {
        guard UUID(uuidString: id) != nil else { throw UFitPublicProfileContractError.outfits }
        if let author {
            guard UUID(uuidString: author.id) != nil, !author.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw UFitPublicProfileContractError.outfits }
            switch author.kind {
            case .creator: guard author.id == creatorID, brandID == nil else { throw UFitPublicProfileContractError.outfits }
            case .brand: guard author.id == brandID, creatorID == nil else { throw UFitPublicProfileContractError.outfits }
            }
        } else if creatorID != nil || brandID != nil { throw UFitPublicProfileContractError.outfits }
    }
}
