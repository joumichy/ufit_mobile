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
    case profileMismatch
    var errorDescription: String? { String(localized: "Le compte Stripe reçu ne correspond pas à cet espace.") }
}
struct UFitConnectLink: Decodable { let url: URL }
extension UFitAPIClient {
    func fetchConnectCountries() async throws -> [String] {
        struct Countries: Decodable { let countries: [String] }
        let result: Countries = try await send(ConnectHTTP.get, path: ConnectHTTP.countries, requiresAuth: true)
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
