import Foundation

private enum WorkspaceHTTP {
    static let get = "GET"; static let patch = "PATCH"; static let cursor = "cursor"
    static let memberships = "me/workspaces"; static let creator = "creators/me"; static let brands = "brands/"
}
private enum WorkspaceContractError: LocalizedError {
    case membershipPage, profileMismatch
    var errorDescription: String? {
        switch self {
        case .membershipPage: String(localized: "La liste des espaces reçue est incohérente. Actualisez pour réessayer.")
        case .profileMismatch: String(localized: "Le profil reçu ne correspond pas à cet espace. Actualisez avant de continuer.")
        }
    }
}
extension UFitAPIClient {
    func fetchWorkspaceMemberships(cursor: String? = nil) async throws -> UFitWorkspaceMemberships {
        let query = cursor.map { [URLQueryItem(name: WorkspaceHTTP.cursor, value: $0)] } ?? []
        return try await send(WorkspaceHTTP.get, path: WorkspaceHTTP.memberships, query: query, requiresAuth: true)
    }
    func fetchAllWorkspaceMemberships() async throws -> UFitWorkspaceMemberships {
        let first = try await fetchWorkspaceMemberships()
        if let creator = first.creator, UUID(uuidString: creator.id) == nil { throw WorkspaceContractError.membershipPage }
        var brands = [UFitWorkspaceMemberships.Brand]()
        var brandIDs = Set<String>()
        var cursors = Set<String>()
        var page = first
        while true {
            guard page.creator?.id == first.creator?.id else { throw WorkspaceContractError.membershipPage }
            for brand in page.brands {
                guard UUID(uuidString: brand.id) != nil, brandIDs.insert(brand.id).inserted else { throw WorkspaceContractError.membershipPage }
                brands.append(brand)
            }
            guard let next = page.nextCursor else { break }
            guard UUID(uuidString: next) != nil, cursors.insert(next).inserted, !page.brands.isEmpty else { throw WorkspaceContractError.membershipPage }
            try Task.checkCancellation()
            page = try await fetchWorkspaceMemberships(cursor: next)
        }
        return UFitWorkspaceMemberships(creator: first.creator, brands: brands, nextCursor: nil)
    }
    func fetchManagedProfile(_ space: UFitWorkspaceReference, userID: String) async throws -> UFitManagedProfileDocument {
        let document: UFitManagedProfileDocument
        switch space {
        case .creator:
            let profile: UFitManagedCreatorProfile = try await send(WorkspaceHTTP.get, path: WorkspaceHTTP.creator, requiresAuth: true)
            guard profile.userId == userID else { throw WorkspaceContractError.profileMismatch }
            document = .creator(profile)
        case .brand:
            let profile: UFitManagedBrandProfile = try await send(WorkspaceHTTP.get, path: WorkspaceHTTP.brands + space.profileID, requiresAuth: true)
            document = .brand(profile)
        }
        guard document.id == space.profileID else { throw WorkspaceContractError.profileMismatch }
        return document
    }
    func saveManagedProfile(_ original: UFitManagedProfileDocument, draft: UFitManagedProfileDraft, userID: String) async throws -> UFitManagedProfileDocument {
        let before = original.draft
        let document: UFitManagedProfileDocument
        switch original {
        case .creator:
            struct Patch: Encodable { let displayName: String?; let bio: String?; let status: UFitProfileStatus?; let socialAccounts: [UFitCreatorSocialAccount]? }
            let socials = draft.socials == before.socials ? nil : draft.socials.map { UFitCreatorSocialAccount(platform: $0.platform, handle: $0.handle, url: $0.url.isEmpty ? nil : $0.url) }
            let profile: UFitManagedCreatorProfile = try await send(WorkspaceHTTP.patch, path: WorkspaceHTTP.creator,
                body: Patch(displayName: draft.name == before.name ? nil : draft.name, bio: draft.bio == before.bio ? nil : draft.bio,
                    status: draft.status == before.status ? nil : draft.status, socialAccounts: socials), requiresAuth: true, publicOutfitsChange: true)
            guard profile.userId == userID else { throw WorkspaceContractError.profileMismatch }
            document = .creator(profile)
        case .brand:
            struct Patch: Encodable { let brandName: String?; let bio: String?; let websiteUrl: String?; let status: UFitProfileStatus? }
            let profile: UFitManagedBrandProfile = try await send(WorkspaceHTTP.patch, path: WorkspaceHTTP.brands + original.id,
                body: Patch(brandName: draft.name == before.name ? nil : draft.name, bio: draft.bio == before.bio ? nil : draft.bio,
                    websiteUrl: draft.website == before.website ? nil : draft.website, status: draft.status == before.status ? nil : draft.status), requiresAuth: true, publicOutfitsChange: true)
            document = .brand(profile)
        }
        guard document.id == original.id else { throw WorkspaceContractError.profileMismatch }
        return document
    }
}
