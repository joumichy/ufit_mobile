import Foundation

enum UFitCatalogStatus: String, Codable, CaseIterable, Identifiable {
    case draft, underReview = "under_review", active, rejected, archived
    var id: String { rawValue }
    var canEdit: Bool { self == .draft || self == .rejected || self == .active }
    var canSubmit: Bool { self == .draft || self == .rejected }
    var label: String {
        switch self { case .draft: Copy.draft; case .underReview: Copy.review; case .active: Copy.active; case .rejected: Copy.rejected; case .archived: Copy.archived }
    }
    private enum Copy {
        static let draft = String(localized: "Brouillon"); static let review = String(localized: "En examen")
        static let active = String(localized: "Validé"); static let rejected = String(localized: "À corriger"); static let archived = String(localized: "Archivé")
    }
}
enum UFitCatalogAccess { case member, moderator }
enum UFitCatalogVariantStatus: String, Codable, CaseIterable, Identifiable {
    case active, outOfStock = "out_of_stock", archived
    var id: String { rawValue }
    var label: String { switch self { case .active: Copy.active; case .outOfStock: Copy.unavailable; case .archived: Copy.archived } }
    private enum Copy { static let active = String(localized: "Active"); static let unavailable = String(localized: "Indisponible"); static let archived = String(localized: "Archivée") }
}
struct UFitCatalogRow: Identifiable {
    let id: String
    let name: String
    let status: UFitCatalogStatus
    let price: String
    let image: String?
}
struct UFitCatalogImage: Identifiable {
    let id: String
    let source: String
    let kindLabel: String
}
struct UFitCatalogVariant: Identifiable {
    let id: String
    let title: String
    let sku: String
    let stockQuantity: Int
    let price: String
    let status: UFitCatalogVariantStatus
}
struct UFitCatalogRevision: Hashable { let id: String; let version: Int }
struct UFitCatalogProductPresentation: Identifiable {
    let id: String
    let version: Int
    let name: String
    let description: String
    let category: String
    let status: UFitCatalogStatus
    let price: String
    let material: String?
    let careInstructions: String?
    let rejectionReason: String?
    let images: [UFitCatalogImage]
    let variants: [UFitCatalogVariant]
    let submissionIssue: String?
    var revision: UFitCatalogRevision { UFitCatalogRevision(id: id, version: version) }
}
