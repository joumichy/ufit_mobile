import Foundation

enum UFitOutfitStatus: String, Codable, CaseIterable, Identifiable {
    case draft, scheduled, published, archived
    var id: String { rawValue }
    var canEdit: Bool { self == .draft || self == .published || self == .scheduled }
    var canPublish: Bool { self == .draft || self == .scheduled }
    var label: String {
        switch self { case .draft: Copy.draft; case .scheduled: Copy.scheduled; case .published: Copy.published; case .archived: Copy.archived }
    }
    private enum Copy {
        static let draft = String(localized: "Brouillon")
        static let scheduled = String(localized: "Programmée")
        static let published = String(localized: "Publiée"); static let archived = String(localized: "Archivée")
    }
}
enum UFitOutfitVisibility: String, Decodable { case `public`, `private`, featured }
enum UFitOutfitAccess { case author, administrator }
struct UFitOutfitScope: Codable, Hashable {
    let profileID: String
    let kind: OutfitAuthor.Kind
    init(profileID: String, kind: OutfitAuthor.Kind) { self.profileID = profileID.lowercased(); self.kind = kind }
    init(workspace: UFitWorkspaceReference) { profileID = workspace.profileID.lowercased(); kind = workspace.isCreator ? .creator : .brand }
}
enum UFitOutfitItemType: String, Codable, CaseIterable, Identifiable {
    case top, bottom, shoes, bag, accessory, outerwear, eyewear, headwear
    var id: String { rawValue }
    var label: String {
        switch self { case .top: Copy.top; case .bottom: Copy.bottom; case .shoes: Copy.shoes; case .bag: Copy.bag; case .accessory: Copy.accessory; case .outerwear: Copy.outerwear; case .eyewear: Copy.eyewear; case .headwear: Copy.headwear }
    }
    var symbol: String {
        switch self { case .top: Icon.top; case .bottom: Icon.bottom; case .shoes: Icon.shoes; case .bag: Icon.bag
        case .accessory: Icon.accessory; case .outerwear: Icon.outerwear; case .eyewear: Icon.eyewear; case .headwear: Icon.headwear }
    }
    private enum Icon { static let top = "tshirt"; static let bottom = "ufit.trousers"; static let shoes = "shoeprints.fill"; static let bag = "handbag"
        static let accessory = "sparkles"; static let outerwear = "jacket"; static let eyewear = "sunglasses"; static let headwear = "hat.cap" }
    private enum Copy {
        static let top = String(localized: "Haut"); static let bottom = String(localized: "Bas"); static let shoes = String(localized: "Chaussures")
        static let eyewear = String(localized: "Lunettes"); static let headwear = String(localized: "Casquette ou chapeau")
        static let bag = String(localized: "Sac"); static let accessory = String(localized: "Accessoire"); static let outerwear = String(localized: "Veste ou manteau")
    }
}
enum UFitOutfitTagType: String, Codable, CaseIterable, Identifiable {
    case style, occasion, season
    var id: String { rawValue }
    var label: String { switch self { case .style: Copy.style; case .occasion: Copy.occasion; case .season: Copy.season } }
    private enum Copy { static let style = String(localized: "Style"); static let occasion = String(localized: "Occasion"); static let season = String(localized: "Saison") }
}
struct UFitOutfitTag: Codable, Hashable, Identifiable { let id: String; let type: UFitOutfitTagType; let slug: String; let label: String }
struct UFitOutfitRevision: Hashable { let id: String; let version: Int }
struct UFitManagedOutfitRow: Identifiable {
    let id: String; let title: String; let author: String?; let image: String?; let status: UFitOutfitStatus; let price: String
}
struct UFitOutfitPiecePresentation: Identifiable {
    let id: String; let title: String; let type: UFitOutfitItemType; let image: String?; let price: String?
    let isRequired: Bool; let isShoppable: Bool; let isAvailable: Bool; let note: String?
}
struct UFitOutfitPhotoPresentation: Identifiable { let id: String; let source: String; var pins: [UFitPhotoPinPresentation] = [] }
struct UFitManagedOutfitPresentation: Identifiable {
    let id: String; let version: Int; let title: String; let description: String; let author: String?
    let status: UFitOutfitStatus; let ownerStatus: UFitProfileStatus?; let price: String
    let photos: [UFitOutfitPhotoPresentation]; let pieces: [UFitOutfitPiecePresentation]; let tags: [UFitOutfitTag]
    let gender: UFitGenderTarget?; let publicationIssue: String?
    var scheduledFor: Date? = nil
    var publicationTimeZone: String? = nil
    var revision: UFitOutfitRevision { .init(id: id, version: version) }
}
