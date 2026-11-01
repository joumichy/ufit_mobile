import Foundation

enum UFitConnectKind: String, Decodable, Hashable { case brand, creator
    var label: String { self == .brand ? String(localized: "Marque") : String(localized: "Créateur") }
}
struct UFitPaymentProfile: Identifiable, Hashable {
    let kind: UFitConnectKind
    let profileID: String
    let name: String
    var id: String { kind.rawValue + ProfileIdentity.separator + profileID }
    private enum ProfileIdentity { static let separator = ":" }
}
struct UFitConnectCountry: Identifiable { let id: String; let name: String }
enum UFitConnectStage: String, Decodable {
    case notStarted = "not_started", incomplete, verifying = "pending_verification", restricted, ready
    var label: String {
        switch self {
        case .notStarted: String(localized: "Configurer votre compte Stripe")
        case .incomplete: String(localized: "Informations à compléter")
        case .verifying: String(localized: "Vérification en cours")
        case .restricted: String(localized: "Compte restreint")
        case .ready: String(localized: "Compte Stripe prêt")
        }
    }
}
struct UFitConnectAccountStatus: Decodable {
    let kind: UFitConnectKind
    let profileId: String
    let country: String?
    let liveMode: Bool
    let canConfigure: Bool
    let stage: UFitConnectStage
    let chargesEnabled: Bool
    let payoutsEnabled: Bool
    let transfersEnabled: Bool
    let missingInformationCount: Int
    let pendingVerificationCount: Int
}
