import Foundation

enum UFitUserRole: String, Decodable, CaseIterable, Identifiable {
    case customer, creator, brandOwner = "brand_owner", brandManager = "brand_manager", admin, superAdmin = "super_admin"
    var id: String { rawValue }

    var administrationLabel: String {
        switch self {
        case .customer: String(localized: "Client")
        case .creator: String(localized: "Créateur")
        case .brandOwner: String(localized: "Propriétaire de marque")
        case .brandManager: String(localized: "Gestionnaire de marque")
        case .admin: String(localized: "Administrateur")
        case .superAdmin: String(localized: "Super-administrateur")
        }
    }
}
