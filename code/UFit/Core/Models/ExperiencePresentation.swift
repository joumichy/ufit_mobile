import Foundation

enum UFitExperienceKind: String, Codable, CaseIterable {
    case customer, creator, brand, administrator
    var title: String {
        switch self { case .customer: Copy.customer; case .creator: Copy.creator; case .brand: Copy.brand; case .administrator: Copy.administrator }
    }
    var tabs: [AppTab] {
        switch self {
        case .customer: [.feed, .search, .saved, .cart, .profile]
        case .creator: [.creatorStudio, .creatorOutfits, .creatorEarnings, .creatorProfile]
        case .brand: [.brandActivity, .brandCatalog, .brandOrders, .brandPublications, .brandProfile]
        case .administrator: [.adminHome, .adminApplications, .adminProducts, .adminOutfits, .profile]
        }
    }
    var homeTab: AppTab {
        switch self { case .customer: .feed; case .creator: .creatorStudio; case .brand: .brandActivity; case .administrator: .adminHome }
    }
    var systemImage: String {
        switch self { case .customer: Icon.customer; case .creator: Icon.creator; case .brand: Icon.brand; case .administrator: Icon.administrator }
    }
    private enum Copy {
        static let customer = String(localized: "Client"); static let creator = String(localized: "Créateur")
        static let brand = String(localized: "Marque"); static let administrator = String(localized: "Administration")
    }
    private enum Icon {
        static let customer = "bag"; static let creator = "person.crop.square"; static let brand = "storefront"; static let administrator = "checkmark.shield"
    }
}
enum UFitExperienceSelection: Codable, Hashable {
    case customer, creator(String), brand(String), administrator
    var kind: UFitExperienceKind {
        switch self { case .customer: .customer; case .creator: .creator; case .brand: .brand; case .administrator: .administrator }
    }
    var profileID: String? { switch self { case .creator(let id), .brand(let id): id; case .customer, .administrator: nil } }
}
struct UFitExperienceChoice: Identifiable, Equatable {
    let selection: UFitExperienceSelection
    let name: String
    let status: UFitProfileStatus?
    var id: UFitExperienceSelection { selection }
    var canSelect: Bool { status == nil || status == .active || status == .paused }
}
struct UFitAdminActivity: Equatable {
    let applications: Int
}
enum UFitProfessionalProfileAction: String, Identifiable {
    case edit, publicProfile, sales, commercePolicy, payments, personalAccount
    var id: String { rawValue }
}
