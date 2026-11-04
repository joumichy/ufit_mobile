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
    case top, shirt, knitwear, hoodie, vest, outerwear
    case bottom, skirt, shorts
    case dress, jumpsuit, swimwear, underwear
    case shoes, sneakers, boots, sandals, heels, socks, tights
    case bag, backpack, clutch
    case eyewear, headwear, hat, beanie, scarf, belt, gloves, watch, necklace, earrings, bracelet, ring, tie, bowtie, hairclip, brooch, umbrella, accessory
    var id: String { rawValue }
    var label: String {
        switch self {
        case .top: Copy.top
        case .shirt: Copy.shirt
        case .knitwear: Copy.knitwear
        case .hoodie: Copy.hoodie
        case .vest: Copy.vest
        case .outerwear: Copy.outerwear
        case .bottom: Copy.bottom
        case .skirt: Copy.skirt
        case .shorts: Copy.shorts
        case .dress: Copy.dress
        case .jumpsuit: Copy.jumpsuit
        case .swimwear: Copy.swimwear
        case .underwear: Copy.underwear
        case .shoes: Copy.shoes
        case .sneakers: Copy.sneakers
        case .boots: Copy.boots
        case .sandals: Copy.sandals
        case .heels: Copy.heels
        case .socks: Copy.socks
        case .tights: Copy.tights
        case .bag: Copy.bag
        case .backpack: Copy.backpack
        case .clutch: Copy.clutch
        case .eyewear: Copy.eyewear
        case .headwear: Copy.headwear
        case .hat: Copy.hat
        case .beanie: Copy.beanie
        case .scarf: Copy.scarf
        case .belt: Copy.belt
        case .gloves: Copy.gloves
        case .watch: Copy.watch
        case .necklace: Copy.necklace
        case .earrings: Copy.earrings
        case .bracelet: Copy.bracelet
        case .ring: Copy.ring
        case .tie: Copy.tie
        case .bowtie: Copy.bowtie
        case .hairclip: Copy.hairclip
        case .brooch: Copy.brooch
        case .umbrella: Copy.umbrella
        case .accessory: Copy.accessory
        }
    }
    var group: Group {
        switch self {
        case .top, .shirt, .knitwear, .hoodie, .vest, .outerwear: .upper
        case .bottom, .skirt, .shorts: .lower
        case .dress, .jumpsuit, .swimwear, .underwear: .fullBody
        case .shoes, .sneakers, .boots, .sandals, .heels, .socks, .tights: .footwear
        case .bag, .backpack, .clutch: .bags
        case .eyewear, .headwear, .hat, .beanie, .scarf, .belt, .gloves, .watch, .necklace, .earrings, .bracelet, .ring, .tie, .bowtie, .hairclip, .brooch, .umbrella, .accessory: .accessories
        }
    }
    enum Group: CaseIterable, Identifiable {
        case upper, lower, fullBody, footwear, bags, accessories
        var id: Self { self }
        var label: String {
            switch self {
            case .upper: String(localized: "Hauts")
            case .lower: String(localized: "Bas")
            case .fullBody: String(localized: "Silhouettes")
            case .footwear: String(localized: "Chaussures et chaussettes")
            case .bags: String(localized: "Sacs")
            case .accessories: String(localized: "Accessoires")
            }
        }
    }
    private enum Copy {
        static let top = String(localized: "Haut")
        static let shirt = String(localized: "Chemise")
        static let knitwear = String(localized: "Pull ou cardigan")
        static let hoodie = String(localized: "Sweat à capuche")
        static let vest = String(localized: "Gilet sans manches")
        static let outerwear = String(localized: "Veste ou manteau")
        static let bottom = String(localized: "Bas")
        static let skirt = String(localized: "Jupe")
        static let shorts = String(localized: "Short")
        static let dress = String(localized: "Robe")
        static let jumpsuit = String(localized: "Combinaison")
        static let swimwear = String(localized: "Maillot de bain")
        static let underwear = String(localized: "Sous-vêtement")
        static let shoes = String(localized: "Chaussures")
        static let sneakers = String(localized: "Baskets")
        static let boots = String(localized: "Bottes ou bottines")
        static let sandals = String(localized: "Sandales")
        static let heels = String(localized: "Chaussures à talons")
        static let socks = String(localized: "Chaussettes")
        static let tights = String(localized: "Collants")
        static let bag = String(localized: "Sac")
        static let backpack = String(localized: "Sac à dos")
        static let clutch = String(localized: "Pochette")
        static let eyewear = String(localized: "Lunettes")
        static let headwear = String(localized: "Casquette ou chapeau")
        static let hat = String(localized: "Chapeau")
        static let beanie = String(localized: "Bonnet")
        static let scarf = String(localized: "Écharpe ou foulard")
        static let belt = String(localized: "Ceinture")
        static let gloves = String(localized: "Gants")
        static let watch = String(localized: "Montre")
        static let necklace = String(localized: "Collier")
        static let earrings = String(localized: "Boucles d’oreilles")
        static let bracelet = String(localized: "Bracelet")
        static let ring = String(localized: "Bague")
        static let tie = String(localized: "Cravate")
        static let bowtie = String(localized: "Nœud papillon")
        static let hairclip = String(localized: "Accessoire de cheveux")
        static let brooch = String(localized: "Broche")
        static let umbrella = String(localized: "Parapluie")
        static let accessory = String(localized: "Autre accessoire")
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
