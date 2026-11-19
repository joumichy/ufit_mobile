import Foundation

enum UFitAccountStatus: String, Codable, CaseIterable, Identifiable {
    case active, onboarding, suspended, deleted
    var id: String { rawValue }
    var label: String {
        switch self {
        case .active: String(localized: "Actif")
        case .onboarding: String(localized: "À compléter")
        case .suspended: String(localized: "Suspendu")
        case .deleted: String(localized: "Supprimé")
        }
    }
}
