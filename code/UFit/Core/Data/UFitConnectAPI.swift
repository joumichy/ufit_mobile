import Foundation

private enum ConnectHTTP {
    static let get = "GET"
    static let post = "POST"
    static let countries = "payments/connect/countries"
    static let base = "payments/connect/"
    static let separator = "/"
    static let onboarding = "/onboarding"
    static let dashboard = "/dashboard"
}
private enum ConnectContractError: LocalizedError {
    case profileMismatch, invalidCountries, invalidRequirements
    private enum Copy { static let invalidRequirements = String(localized: "Les informations du compte Stripe sont indisponibles. Réessayez.") }
    var errorDescription: String? {
        switch self {
        case .profileMismatch: String(localized: "Le compte Stripe reçu ne correspond pas à cet espace.")
        case .invalidCountries: String(localized: "Les pays d’établissement sont indisponibles. Réessayez.")
        case .invalidRequirements: Copy.invalidRequirements
        }
    }
}
private enum ConnectCountryCode { static let length = 2; static let uppercaseASCII: ClosedRange<UInt8> = 65...90 }
struct UFitConnectLink: Decodable { let url: URL }
extension UFitAPIClient {
    func fetchConnectCountries(reload: Bool = false) async throws -> [String] {
        struct Countries: Decodable { let countries: [String] }
        let result: Countries = try await fetchReference(path: ConnectHTTP.countries, reload: reload) { (result: Countries) in
            guard !result.countries.isEmpty, Set(result.countries).count == result.countries.count,
                  result.countries.allSatisfy({ $0.utf8.count == ConnectCountryCode.length && $0.utf8.allSatisfy(ConnectCountryCode.uppercaseASCII.contains) }) else {
                throw ConnectContractError.invalidCountries
            }
        }
        return result.countries
    }
    func fetchConnectStatus(_ profile: UFitPaymentProfile) async throws -> UFitConnectAccountStatus {
        let status: UFitConnectAccountStatus
        do {
            status = try await send(ConnectHTTP.get, path: ConnectHTTP.base + profile.kind.rawValue + ConnectHTTP.separator + profile.profileID, requiresAuth: true)
        } catch is DecodingError { throw ConnectContractError.invalidRequirements }
        guard status.kind == profile.kind, status.profileId == profile.profileID else { throw ConnectContractError.profileMismatch }
        guard status.requirements.isValid(missingCount: status.missingInformationCount, pendingCount: status.pendingVerificationCount) else {
            throw ConnectContractError.invalidRequirements
        }
        return status
    }
    func createConnectOnboarding(_ profile: UFitPaymentProfile, country: String) async throws -> UFitConnectLink {
        struct Request: Encodable { let country: String }
        return try await send(ConnectHTTP.post, path: ConnectHTTP.base + profile.kind.rawValue + ConnectHTTP.separator + profile.profileID + ConnectHTTP.onboarding, body: Request(country: country), requiresAuth: true, publicOutfitsChange: false)
    }
    func createConnectDashboard(_ profile: UFitPaymentProfile) async throws -> UFitConnectLink {
        try await send(ConnectHTTP.post, path: ConnectHTTP.base + profile.kind.rawValue + ConnectHTTP.separator + profile.profileID + ConnectHTTP.dashboard, requiresAuth: true, publicOutfitsChange: false)
    }
}
