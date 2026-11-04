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
    case profileMismatch, invalidCountries
    var errorDescription: String? {
        switch self {
        case .profileMismatch: String(localized: "Le compte Stripe reçu ne correspond pas à cet espace.")
        case .invalidCountries: String(localized: "Les pays d’établissement sont indisponibles. Réessayez.")
        }
    }
}
private enum ConnectCountryCode { static let length = 2; static let uppercaseASCII: ClosedRange<UInt8> = 65...90 }
struct UFitConnectLink: Decodable { let url: URL }
extension UFitAPIClient {
    func fetchConnectCountries() async throws -> [String] {
        struct Countries: Decodable { let countries: [String] }
        let result: Countries = try await send(ConnectHTTP.get, path: ConnectHTTP.countries, requiresAuth: true)
        guard !result.countries.isEmpty, Set(result.countries).count == result.countries.count,
              result.countries.allSatisfy({ $0.utf8.count == ConnectCountryCode.length && $0.utf8.allSatisfy(ConnectCountryCode.uppercaseASCII.contains) }) else {
            throw ConnectContractError.invalidCountries
        }
        return result.countries
    }
    func fetchConnectStatus(_ profile: UFitPaymentProfile) async throws -> UFitConnectAccountStatus {
        let status: UFitConnectAccountStatus = try await send(ConnectHTTP.get, path: ConnectHTTP.base + profile.kind.rawValue + ConnectHTTP.separator + profile.profileID, requiresAuth: true)
        guard status.kind == profile.kind, status.profileId == profile.profileID else { throw ConnectContractError.profileMismatch }
        return status
    }
    func createConnectOnboarding(_ profile: UFitPaymentProfile, country: String) async throws -> UFitConnectLink {
        struct Request: Encodable { let country: String }
        return try await send(ConnectHTTP.post, path: ConnectHTTP.base + profile.kind.rawValue + ConnectHTTP.separator + profile.profileID + ConnectHTTP.onboarding, body: Request(country: country), requiresAuth: true)
    }
    func createConnectDashboard(_ profile: UFitPaymentProfile) async throws -> UFitConnectLink {
        try await send(ConnectHTTP.post, path: ConnectHTTP.base + profile.kind.rawValue + ConnectHTTP.separator + profile.profileID + ConnectHTTP.dashboard, requiresAuth: true)
    }
}
