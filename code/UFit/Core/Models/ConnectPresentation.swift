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
struct UFitConnectCountry: Identifiable {
    let id: String
    let name: String
    private static let locale = Locale(identifier: "fr")
    static func localizedName(_ code: String) -> String { locale.localizedString(forRegionCode: code) ?? code }
}
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
    let requirements: UFitConnectRequirements
}
enum UFitConnectRequirementCategory: String, Decodable, Hashable {
    case personalDetails = "personal_details", businessDetails = "business_details", bankAccount = "bank_account"
    case documents, serviceAgreement = "service_agreement", additionalInformation = "additional_information"
    private enum Copy {
        static let personal = String(localized: "Informations personnelles")
        static let business = String(localized: "Votre activité")
        static let bank = String(localized: "Compte bancaire")
        static let documents = String(localized: "Pièces justificatives")
        static let agreement = String(localized: "Accord Stripe")
        static let additional = String(localized: "Informations complémentaires")
    }
    private enum Symbol {
        static let personal = "person.crop.rectangle", business = "building.2", bank = "building.columns"
        static let documents = "doc.text", agreement = "signature", additional = "info.circle"
    }
    var title: String {
        switch self {
        case .personalDetails: Copy.personal
        case .businessDetails: Copy.business
        case .bankAccount: Copy.bank
        case .documents: Copy.documents
        case .serviceAgreement: Copy.agreement
        case .additionalInformation: Copy.additional
        }
    }
    var symbol: String {
        switch self {
        case .personalDetails: Symbol.personal
        case .businessDetails: Symbol.business
        case .bankAccount: Symbol.bank
        case .documents: Symbol.documents
        case .serviceAgreement: Symbol.agreement
        case .additionalInformation: Symbol.additional
        }
    }
}
struct UFitConnectRequirements: Decodable {
    let missing: [UFitConnectRequirementCategory]
    let pending: [UFitConnectRequirementCategory]
    func isValid(missingCount: Int, pendingCount: Int) -> Bool {
        valid(missing, fieldCount: missingCount) && valid(pending, fieldCount: pendingCount)
    }
    private func valid(_ categories: [UFitConnectRequirementCategory], fieldCount: Int) -> Bool {
        fieldCount >= .zero && categories.count <= fieldCount && categories.isEmpty == (fieldCount == .zero)
            && Set(categories).count == categories.count
    }
}
