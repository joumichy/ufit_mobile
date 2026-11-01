import Foundation

private enum AdminActivityHTTP {
    static let get = "GET"; static let path = "admin/activity"
    static let maximumCount = 9_007_199_254_740_991
}
private struct AdminActivityDTO: Decodable {
    let applications: Int; let products: Int; let outfits: Int
    private enum CodingKeys: String, CodingKey, CaseIterable { case applications, products, outfits }
    init(from decoder: Decoder) throws {
        try UFitStrictDecoding.keys(decoder, CodingKeys.self, failure: UFitAdminActivityFailure.invalid)
        let values = try decoder.container(keyedBy: CodingKeys.self)
        applications = try values.decode(Int.self, forKey: .applications)
        products = try values.decode(Int.self, forKey: .products)
        outfits = try values.decode(Int.self, forKey: .outfits)
        guard [applications, products, outfits].allSatisfy({ (.zero...AdminActivityHTTP.maximumCount).contains($0) }) else { throw UFitAdminActivityFailure.invalid }
    }
}
enum UFitAdminActivityFailure: LocalizedError {
    case invalid
    var errorDescription: String? { String(localized: "Les compteurs sont indisponibles. Actualisez les dossiers.") }
}
extension UFitAPIClient {
    func fetchAdminActivity() async throws -> UFitAdminActivity {
        let value: AdminActivityDTO = try await send(AdminActivityHTTP.get, path: AdminActivityHTTP.path, requiresAuth: true)
        return .init(applications: value.applications, products: value.products, outfits: value.outfits)
    }
}
