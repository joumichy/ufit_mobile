import Foundation

enum UFitProfileStatus: String, Codable, CaseIterable, Identifiable {
    case draft, active, paused, suspended
    var id: String { rawValue }
    var canEdit: Bool { self != .suspended }
    var canChangeVisibility: Bool { self == .active || self == .paused }
    var label: String {
        switch self {
        case .draft: Copy.draft
        case .active: Copy.active
        case .paused: Copy.paused
        case .suspended: Copy.suspended
        }
    }
    private enum Copy {
        static let draft = String(localized: "Brouillon")
        static let active = String(localized: "Actif")
        static let paused = String(localized: "En pause")
        static let suspended = String(localized: "Suspendu")
    }
}
enum UFitBrandMemberRole: String, Decodable, Hashable {
    case owner, manager
    var label: String { self == .owner ? Copy.owner : Copy.manager }
    private enum Copy {
        static let owner = String(localized: "Propriétaire")
        static let manager = String(localized: "Gestionnaire")
    }
}
struct UFitWorkspaceMemberships: Decodable {
    struct Creator: Decodable, Hashable { let id: String; let displayName: String; let status: UFitProfileStatus }
    struct Brand: Decodable, Hashable { let id: String; let brandName: String; let status: UFitProfileStatus; let memberRole: UFitBrandMemberRole }
    let creator: Creator?
    let brands: [Brand]
    let nextCursor: String?
}
enum UFitWorkspaceReference: Hashable, Identifiable {
    case creator(UFitWorkspaceMemberships.Creator)
    case brand(UFitWorkspaceMemberships.Brand)
    var profileID: String {
        switch self { case .creator(let profile): profile.id; case .brand(let profile): profile.id }
    }
    var id: String { (isCreator ? Wire.creatorKind : Wire.brandKind) + Wire.separator + profileID }
    var isCreator: Bool { if case .creator = self { true } else { false } }
    var name: String {
        switch self { case .creator(let profile): profile.displayName; case .brand(let profile): profile.brandName }
    }
    var status: UFitProfileStatus {
        switch self { case .creator(let profile): profile.status; case .brand(let profile): profile.status }
    }
    var kindLabel: String {
        switch self { case .creator: Copy.creator; case .brand: Copy.brand }
    }
    var roleLabel: String? { if case .brand(let profile) = self { profile.memberRole.label } else { nil } }
    var systemImage: String { if case .creator = self { Wire.creatorIcon } else { Wire.brandIcon } }
    private enum Wire { static let creatorKind = "creator"; static let brandKind = "brand"; static let separator = ":"; static let creatorIcon = "person.crop.square"; static let brandIcon = "tag" }
    private enum Copy { static let creator = String(localized: "Créateur"); static let brand = String(localized: "Marque") }
}
enum UFitSocialPlatform: String, Codable, CaseIterable, Identifiable {
    case instagram, tiktok, youtube, pinterest, website, other
    var id: String { rawValue }
    var label: String {
        switch self {
        case .instagram: Copy.instagram
        case .tiktok: Copy.tiktok
        case .youtube: Copy.youtube
        case .pinterest: Copy.pinterest
        case .website: Copy.website
        case .other: Copy.other
        }
    }
    private enum Copy {
        static let instagram = "Instagram"; static let tiktok = "TikTok"; static let youtube = "YouTube"; static let pinterest = "Pinterest"
        static let website = String(localized: "Site personnel"); static let other = String(localized: "Autre réseau")
    }
}
struct UFitCreatorSocialAccount: Codable, Hashable {
    let platform: UFitSocialPlatform
    let handle: String
    let url: String?
}
struct UFitManagedCreatorProfile: Decodable {
    let id: String
    let userId: String
    let displayName: String
    let bio: String?
    let avatarUrl: String?
    let status: UFitProfileStatus
    let socialAccounts: [UFitCreatorSocialAccount]
}
struct UFitManagedBrandProfile: Decodable {
    let id: String
    let ownerUserId: String
    let brandName: String
    let bio: String?
    let websiteUrl: String?
    let status: UFitProfileStatus
}
enum UFitManagedProfileDocument {
    case creator(UFitManagedCreatorProfile), brand(UFitManagedBrandProfile)
    var id: String { switch self { case .creator(let profile): profile.id; case .brand(let profile): profile.id } }
    var isCreator: Bool { if case .creator = self { true } else { false } }
    var draft: UFitManagedProfileDraft {
        switch self {
        case .creator(let profile):
            UFitManagedProfileDraft(name: profile.displayName, bio: profile.bio ?? String(), website: String(), status: profile.status,
                socials: profile.socialAccounts.map { UFitSocialDraft(platform: $0.platform, handle: $0.handle, url: $0.url ?? String()) })
        case .brand(let profile):
            UFitManagedProfileDraft(name: profile.brandName, bio: profile.bio ?? String(), website: profile.websiteUrl ?? String(), status: profile.status, socials: [])
        }
    }
}
struct UFitSocialDraft: Identifiable, Hashable {
    let platform: UFitSocialPlatform
    var handle = String()
    var url = String()
    var id: UFitSocialPlatform { platform }
}
struct UFitManagedProfileDraft: Hashable {
    var name: String
    var bio: String
    var website: String
    var status: UFitProfileStatus
    var socials: [UFitSocialDraft]
    var availablePlatforms: [UFitSocialPlatform] { UFitSocialPlatform.allCases.filter { platform in !socials.contains { $0.platform == platform } } }
}
enum UFitProfileField: Hashable { case name, bio, website, handle(UFitSocialPlatform), socialURL(UFitSocialPlatform) }
