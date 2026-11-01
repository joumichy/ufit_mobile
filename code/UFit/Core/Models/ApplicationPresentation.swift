import Foundation

enum UFitApplicationKind: String, Codable, CaseIterable, Identifiable {
    case creator, brand
    private enum Copy {
        static let creator = String(localized: "Créateur")
        static let brand = String(localized: "Marque")
        static let creatorTitle = String(localized: "Devenir créateur")
        static let brandTitle = String(localized: "Proposer ma marque")
    }
    var id: String { rawValue }
    var label: String { self == .creator ? Copy.creator : Copy.brand }
    var title: String { self == .creator ? Copy.creatorTitle : Copy.brandTitle }
    var collection: String { self == .creator ? Wire.creators : Wire.brands }
    private enum Wire { static let creators = "creators"; static let brands = "brands" }
}
enum UFitApplicationStatus: String, Decodable {
    case submitted, underReview = "under_review", accepted, rejected, waitlisted, needsMoreInfo = "needs_more_info"
    private enum Copy {
        static let submitted = String(localized: "Envoyée")
        static let underReview = String(localized: "En examen")
        static let accepted = String(localized: "Acceptée")
        static let rejected = String(localized: "Refusée")
        static let waitlisted = String(localized: "En liste d’attente")
        static let needsMoreInfo = String(localized: "Compléments demandés")
    }
    var label: String {
        switch self {
        case .submitted: Copy.submitted
        case .underReview: Copy.underReview
        case .accepted: Copy.accepted
        case .rejected: Copy.rejected
        case .waitlisted: Copy.waitlisted
        case .needsMoreInfo: Copy.needsMoreInfo
        }
    }
    var canCorrect: Bool { self == .rejected || self == .needsMoreInfo }
    var canReview: Bool { self != .accepted && self != .rejected }
}
enum UFitApplicationDecision: String, Codable, CaseIterable, Identifiable {
    case accept, reject, waitlist, needsMoreInfo = "needs_more_info"
    private enum Copy {
        static let accept = String(localized: "Accepter")
        static let reject = String(localized: "Refuser")
        static let waitlist = String(localized: "Mettre en liste d’attente")
        static let needsMoreInfo = String(localized: "Demander des compléments")
    }
    var id: String { rawValue }
    var label: String {
        switch self {
        case .accept: Copy.accept
        case .reject: Copy.reject
        case .waitlist: Copy.waitlist
        case .needsMoreInfo: Copy.needsMoreInfo
        }
    }
}
struct UFitApplicationTimestamp: Decodable {
    let value: Date
    init(value: Date) { self.value = value }
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let text = try container.decode(String.self)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let value = formatter.date(from: text) else { throw DecodingError.dataCorruptedError(in: container, debugDescription: Wire.invalid) }
        self.value = value
    }
    var label: String { value.formatted(.dateTime.day().month(.wide).year().locale(Wire.locale)) }
    private enum Wire { static let invalid = "Invalid application timestamp"; static let locale = Locale(identifier: "fr_CH") }
}
struct UFitApplicationReview: Decodable { let decision: UFitApplicationDecision; let notes: String?; let createdAt: UFitApplicationTimestamp }
struct UFitApplicationMetadata: Decodable {
    let id: String
    let type: UFitApplicationKind
    let userId: String
    let status: UFitApplicationStatus
    let version: Int
    let submittedAt: UFitApplicationTimestamp
    let updatedAt: UFitApplicationTimestamp
    let latestReview: UFitApplicationReview?
}
struct UFitCreatorApplicationDossier: Codable {
    let instagramUrl: String
    let tiktokUrl: String?
    let dominantStyle: String
    let brandsWorn: String
    let outfitExampleUrls: [String]
}
struct UFitBrandApplicationDossier: Codable {
    let instagramUrl: String
    let country: String
    let priceRange: String
    let lookbookUrl: String
    let shippingCapabilities: String
    let returnPolicy: String
    let commissionProposal: String?
}
struct UFitCreatorApplicationPayload: Decodable { let displayName: String; let email: String; let portfolioUrl: String?; let motivation: String; let audienceSummary: String?; let dossier: UFitCreatorApplicationDossier? }
struct UFitBrandApplicationPayload: Decodable { let brandName: String; let email: String; let websiteUrl: String; let productCategory: String; let positioning: String; let dossier: UFitBrandApplicationDossier? }
struct UFitApplicationDocument: Decodable, Identifiable {
    enum Payload { case creator(UFitCreatorApplicationPayload), brand(UFitBrandApplicationPayload) }
    let metadata: UFitApplicationMetadata
    let payload: Payload
    var id: String { metadata.id }
    init(metadata: UFitApplicationMetadata, payload: Payload) { self.metadata = metadata; self.payload = payload }
    init(from decoder: Decoder) throws {
        metadata = try UFitApplicationMetadata(from: decoder)
        switch metadata.type {
        case .creator: payload = .creator(try UFitCreatorApplicationPayload(from: decoder))
        case .brand: payload = .brand(try UFitBrandApplicationPayload(from: decoder))
        }
    }
    var name: String { switch payload { case .creator(let value): value.displayName; case .brand(let value): value.brandName } }
    var hasDossier: Bool { switch payload { case .creator(let value): value.dossier != nil; case .brand(let value): value.dossier != nil } }
    var formValues: [UFitApplicationField: String] {
        var fields: [UFitApplicationField: String]
        switch payload {
        case .creator(let value):
            fields = [.name: value.displayName, .email: value.email, .motivation: value.motivation]
            fields[.portfolio] = value.portfolioUrl; fields[.audience] = value.audienceSummary
            if let dossier = value.dossier {
                fields[.instagram] = dossier.instagramUrl; fields[.tiktok] = dossier.tiktokUrl
                fields[.style] = dossier.dominantStyle; fields[.brandsWorn] = dossier.brandsWorn
                for (field, url) in zip(UFitApplicationField.examples, dossier.outfitExampleUrls) { fields[field] = url }
            }
        case .brand(let value):
            fields = [.name: value.brandName, .email: value.email, .website: value.websiteUrl, .category: value.productCategory, .positioning: value.positioning]
            if let dossier = value.dossier {
                fields[.instagram] = dossier.instagramUrl; fields[.country] = dossier.country
                fields[.priceRange] = dossier.priceRange; fields[.lookbook] = dossier.lookbookUrl
                fields[.shipping] = dossier.shippingCapabilities; fields[.returns] = dossier.returnPolicy
                fields[.commission] = dossier.commissionProposal
            }
        }
        return fields
    }
}
enum UFitApplicationField: String, CaseIterable, Identifiable {
    case name, email, instagram, tiktok, portfolio, style, brandsWorn, exampleOne, exampleTwo, exampleThree, motivation, audience
    case website, country, category, positioning, priceRange, lookbook, shipping, returns, commission
    private enum Copy {
        static let creatorName = String(localized: "Nom ou pseudonyme")
        static let brandName = String(localized: "Nom de marque")
        static let email = String(localized: "E-mail de contact")
        static let instagram = String(localized: "Lien Instagram")
        static let tiktok = String(localized: "Lien TikTok (facultatif)")
        static let portfolio = String(localized: "Portfolio (facultatif)")
        static let style = String(localized: "Style dominant")
        static let brandsWorn = String(localized: "Marques déjà portées")
        static let exampleOne = String(localized: "Première tenue · lien")
        static let exampleTwo = String(localized: "Deuxième tenue · lien")
        static let exampleThree = String(localized: "Troisième tenue · lien")
        static let motivation = String(localized: "Pourquoi rejoindre Ufit ?")
        static let audience = String(localized: "Votre audience (facultatif)")
        static let website = String(localized: "Site web")
        static let country = String(localized: "Pays d’établissement")
        static let category = String(localized: "Catégorie principale")
        static let positioning = String(localized: "Présentez votre marque")
        static let priceRange = String(localized: "Fourchette de prix indicative")
        static let lookbook = String(localized: "Lookbook ou catalogue · lien")
        static let shipping = String(localized: "Vos possibilités d’expédition")
        static let returns = String(localized: "Votre politique de retour")
        static let commission = String(localized: "Proposition commerciale (facultatif)")
    }
    var id: String { rawValue }
    static let examples: [Self] = [.exampleOne, .exampleTwo, .exampleThree]
    static func fields(for kind: UFitApplicationKind) -> [Self] {
        switch kind {
        case .creator: [.name, .email, .instagram, .tiktok, .portfolio, .style, .brandsWorn, .exampleOne, .exampleTwo, .exampleThree, .motivation, .audience]
        case .brand: [.name, .email, .website, .instagram, .country, .category, .priceRange, .positioning, .lookbook, .shipping, .returns, .commission]
        }
    }
    func label(for kind: UFitApplicationKind) -> String {
        switch self {
        case .name: kind == .creator ? Copy.creatorName : Copy.brandName
        case .email: Copy.email
        case .instagram: Copy.instagram
        case .tiktok: Copy.tiktok
        case .portfolio: Copy.portfolio
        case .style: Copy.style
        case .brandsWorn: Copy.brandsWorn
        case .exampleOne: Copy.exampleOne
        case .exampleTwo: Copy.exampleTwo
        case .exampleThree: Copy.exampleThree
        case .motivation: Copy.motivation
        case .audience: Copy.audience
        case .website: Copy.website
        case .country: Copy.country
        case .category: Copy.category
        case .positioning: Copy.positioning
        case .priceRange: Copy.priceRange
        case .lookbook: Copy.lookbook
        case .shipping: Copy.shipping
        case .returns: Copy.returns
        case .commission: Copy.commission
        }
    }
    var isOptional: Bool { [.tiktok, .portfolio, .audience, .commission].contains(self) }
    var isLink: Bool { [.instagram, .tiktok, .portfolio, .exampleOne, .exampleTwo, .exampleThree, .website, .lookbook].contains(self) }
    var isMultiline: Bool { [.motivation, .audience, .brandsWorn, .positioning, .shipping, .returns, .commission].contains(self) }
}
struct UFitApplicationQueueItem: Decodable {
    var identity: String { type.rawValue + Wire.separator + id }
    private enum Wire { static let separator = ":" }
    let id: String; let type: UFitApplicationKind; let name: String; let status: UFitApplicationStatus; let version: Int
    let submittedAt: UFitApplicationTimestamp; let updatedAt: UFitApplicationTimestamp
}
enum UFitApplicationQueueFilter: String, CaseIterable, Identifiable {
    case pending, waitlisted, needsMoreInfo = "needs_more_info", accepted, rejected, all
    private enum Copy {
        static let pending = String(localized: "À examiner")
        static let waitlisted = String(localized: "Liste d’attente")
        static let needsMoreInfo = String(localized: "Compléments demandés")
        static let accepted = String(localized: "Acceptées")
        static let rejected = String(localized: "Refusées")
        static let all = String(localized: "Toutes")
    }
    var id: String { rawValue }
    var label: String {
        switch self {
        case .pending: Copy.pending
        case .waitlisted: Copy.waitlisted
        case .needsMoreInfo: Copy.needsMoreInfo
        case .accepted: Copy.accepted
        case .rejected: Copy.rejected
        case .all: Copy.all
        }
    }
}
