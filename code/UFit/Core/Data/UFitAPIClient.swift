import Foundation

struct UFitAPIConfiguration {
    let baseURL: URL
    let bearerToken: String?
    let brandProfileID: String?

    static func live(environment: [String: String] = ProcessInfo.processInfo.environment) -> UFitAPIConfiguration {
        let rawBaseURL = environment["UFIT_API_BASE_URL"] ?? "http://127.0.0.1:4000"
        return UFitAPIConfiguration(
            baseURL: URL(string: rawBaseURL) ?? URL(string: "http://127.0.0.1:4000")!,
            bearerToken: environment["UFIT_API_BEARER_TOKEN"].flatMap { $0.isEmpty ? nil : $0 },
            brandProfileID: environment["UFIT_BRAND_PROFILE_ID"].flatMap { $0.isEmpty ? nil : $0 }
        )
    }
}

enum UFitAPIError: LocalizedError {
    case authenticationRequired
    case invalidURL
    case requestFailed(statusCode: Int, message: String)
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case .authenticationRequired:
            "Connect a UFit session to continue."
        case .invalidURL:
            "The UFit API URL is invalid."
        case .requestFailed(let statusCode, let message):
            message.isEmpty ? "UFit API request failed with status \(statusCode)." : message
        case .emptyResponse:
            "The UFit API returned an empty response."
        }
    }
}

struct UFitAPIClient {
    let configuration: UFitAPIConfiguration
    private let session: URLSession
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    init(configuration: UFitAPIConfiguration = .live(), session: URLSession = .shared) {
        self.configuration = configuration
        self.session = session
    }

    func fetchOutfitFeed(limit: Int = 20, cursor: String? = nil) async throws -> UFitFeedResponseDTO {
        var query = [URLQueryItem(name: "limit", value: String(limit))]
        if let cursor {
            query.append(URLQueryItem(name: "cursor", value: cursor))
        }
        return try await send("GET", path: "outfits", query: query)
    }

    func fetchOutfitDetail(id: String) async throws -> UFitOutfitDetailDTO {
        try await send("GET", path: "outfits/\(id)")
    }

    func saveOutfit(id: String) async throws -> UFitSavedActionDTO {
        try await send("PUT", path: "me/saved-outfits/\(id)", requiresAuth: true)
    }

    func unsaveOutfit(id: String) async throws -> UFitSavedActionDTO {
        try await send("DELETE", path: "me/saved-outfits/\(id)", requiresAuth: true)
    }

    func addCartItem(_ body: UFitAddCartItemRequest) async throws -> UFitCartDTO {
        try await send("POST", path: "cart/items", body: body, requiresAuth: true)
    }

    func checkout(_ body: UFitCheckoutRequest) async throws -> UFitCheckoutSessionDTO {
        try await send("POST", path: "orders/checkout", body: body, requiresAuth: true)
    }

    func fetchPublicProduct(id: String) async throws -> UFitPublicProductDTO {
        try await send("GET", path: "products/\(id)/public")
    }

    func fetchCreatorDashboard() async throws -> UFitCreatorDashboardDTO {
        try await send("GET", path: "creators/me/dashboard", requiresAuth: true)
    }

    func fetchCreatorOutfits(limit: Int = 20) async throws -> UFitCreatorOutfitsDTO {
        try await send("GET", path: "creators/me/outfits", query: [URLQueryItem(name: "limit", value: String(limit))], requiresAuth: true)
    }

    func fetchCreatorCommissions(limit: Int = 20) async throws -> UFitCreatorCommissionsDTO {
        try await send("GET", path: "creators/me/commissions", query: [URLQueryItem(name: "limit", value: String(limit))], requiresAuth: true)
    }

    func fetchBrandDashboard(brandProfileID: String) async throws -> UFitBrandDashboardDTO {
        try await send("GET", path: "brands/\(brandProfileID)/dashboard", requiresAuth: true)
    }

    func fetchBrandProducts(brandProfileID: String, limit: Int = 20) async throws -> UFitBrandProductsDTO {
        try await send("GET", path: "brands/\(brandProfileID)/products", query: [URLQueryItem(name: "limit", value: String(limit))], requiresAuth: true)
    }

    func fetchBrandOrders(brandProfileID: String, limit: Int = 20) async throws -> UFitBrandOrdersDTO {
        try await send("GET", path: "brands/\(brandProfileID)/orders", query: [URLQueryItem(name: "limit", value: String(limit))], requiresAuth: true)
    }

    private func send<Response: Decodable, Body: Encodable>(
        _ method: String,
        path: String,
        query: [URLQueryItem] = [],
        body: Body,
        requiresAuth: Bool = false
    ) async throws -> Response {
        try await send(method, path: path, query: query, bodyData: encoder.encode(body), requiresAuth: requiresAuth)
    }

    private func send<Response: Decodable>(
        _ method: String,
        path: String,
        query: [URLQueryItem] = [],
        requiresAuth: Bool = false
    ) async throws -> Response {
        try await send(method, path: path, query: query, bodyData: nil, requiresAuth: requiresAuth)
    }

    private func send<Response: Decodable>(
        _ method: String,
        path: String,
        query: [URLQueryItem],
        bodyData: Data?,
        requiresAuth: Bool
    ) async throws -> Response {
        if requiresAuth, configuration.bearerToken == nil {
            throw UFitAPIError.authenticationRequired
        }

        guard let url = makeURL(path: path, query: query) else {
            throw UFitAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let bodyData {
            request.httpBody = bodyData
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        if let token = configuration.bearerToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw UFitAPIError.emptyResponse
        }
        guard 200..<300 ~= httpResponse.statusCode else {
            throw UFitAPIError.requestFailed(statusCode: httpResponse.statusCode, message: String(data: data, encoding: .utf8) ?? "")
        }
        guard !data.isEmpty else {
            throw UFitAPIError.emptyResponse
        }
        return try decoder.decode(Response.self, from: data)
    }

    private func makeURL(path: String, query: [URLQueryItem]) -> URL? {
        let trimmedPath = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        var url = configuration.baseURL
        for part in trimmedPath.split(separator: "/") {
            url.appendPathComponent(String(part))
        }
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }
        components.queryItems = query.isEmpty ? nil : query
        return components.url
    }
}

struct UFitFeedResponseDTO: Decodable {
    let items: [UFitOutfitCardDTO]
    let nextCursor: String?
}

struct UFitOutfitCardDTO: Decodable {
    let id: String
    let title: String
    let coverImageUrl: String
    let totalPriceMin: Int
    let totalPriceMax: Int
    let currency: String
    let publishedAt: String?
}

struct UFitOutfitDetailDTO: Decodable {
    let id: String
    let title: String
    let coverImageUrl: String
    let totalPriceMin: Int
    let totalPriceMax: Int
    let currency: String
    let publishedAt: String?
    let description: String
    let creatorId: String?
    let brandId: String?
    let items: [UFitOutfitItemDTO]
}

struct UFitOutfitItemDTO: Decodable {
    let id: String
    let itemType: String
    let label: String
    let position: Int
    let isRequired: Bool
    let isShoppable: Bool
    let stylingNote: String?
    let product: UFitOutfitProductDTO?
}

struct UFitOutfitProductDTO: Decodable {
    let id: String
    let name: String
    let brandId: String
    let price: Int
    let currency: String
    let imageUrl: String?
}

struct UFitPublicProductDTO: Decodable {
    let id: String
    let brandId: String
    let name: String
    let price: UFitProductPriceDTO
    let variants: [UFitProductVariantDTO]
}

struct UFitProductPriceDTO: Decodable {
    let min: Int
    let max: Int
    let currency: String
}

struct UFitProductVariantDTO: Decodable {
    let id: String
    let size: String?
    let color: String?
    let stockQuantity: Int
    let price: Int
}

struct UFitSavedActionDTO: Decodable {
    let saved: Bool?
}

struct UFitCartDTO: Decodable {
    let id: String
    let subtotalAmount: Int
    let currency: String
}

struct UFitAddCartItemRequest: Encodable {
    let productVariantId: String
    let quantity: Int
    let sourceOutfitId: String?
    let sourceCreatorId: String?
}

struct UFitShippingAddress: Encodable {
    var fullName: String
    var line1: String
    var line2: String?
    var postalCode: String
    var city: String
    var country: String
    var phone: String?
}

struct UFitCheckoutRequest: Encodable {
    let shippingAddress: UFitShippingAddress
    let shippingAmount: Int?
}

struct UFitCheckoutSessionDTO: Decodable {
    let orderId: String
    let checkoutSessionId: String
    let url: String
}

struct UFitCreatorDashboardDTO: Decodable {
    let profile: UFitCreatorWorkspaceProfileDTO
    let performance: UFitCreatorPerformanceDTO
}

struct UFitCreatorWorkspaceProfileDTO: Decodable {
    let id: String
    let displayName: String
    let slug: String
    let status: String
    let grade: UFitCreatorGradeDTO
}

struct UFitCreatorGradeDTO: Decodable {
    let code: String
    let label: String
    let rank: Int
    let commissionBps: Int
}

struct UFitCreatorPerformanceDTO: Decodable {
    let outfits: UFitCreatorOutfitMetricsDTO
    let commissions: UFitCreatorCommissionMetricsDTO
    let sales: UFitSalesMetricsDTO
}

struct UFitCreatorOutfitMetricsDTO: Decodable {
    let total: Int
    let draft: Int
    let underReview: Int
    let published: Int
    let rejected: Int
}

struct UFitCreatorCommissionMetricsDTO: Decodable {
    let pendingAmount: Int
    let validatedAmount: Int
    let paidAmount: Int
    let totalAmount: Int
    let pendingCount: Int
    let validatedCount: Int
    let paidCount: Int
}

struct UFitSalesMetricsDTO: Decodable {
    let paidOrderCount: Int
    let grossAmount: Int
    let currency: String
}

struct UFitCreatorOutfitsDTO: Decodable {
    let items: [UFitCreatorOutfitDTO]
}

struct UFitCreatorOutfitDTO: Decodable {
    let id: String
    let title: String
    let status: String
    let totalPriceMax: Int
    let publishedAt: String?
}

struct UFitCreatorCommissionsDTO: Decodable {
    let items: [UFitCreatorCommissionDTO]
}

struct UFitCreatorCommissionDTO: Decodable {
    let id: String
    let status: String
    let commissionAmount: Int
    let createdAt: String?
}

struct UFitBrandDashboardDTO: Decodable {
    let profile: UFitBrandWorkspaceProfileDTO
    let performance: UFitBrandPerformanceDTO
}

struct UFitBrandWorkspaceProfileDTO: Decodable {
    let id: String
    let brandName: String
    let slug: String
    let status: String
    let memberRole: String
}

struct UFitBrandPerformanceDTO: Decodable {
    let products: UFitBrandProductMetricsDTO
    let orders: UFitBrandOrderMetricsDTO
    let sales: UFitSalesMetricsDTO
    let stock: UFitBrandStockMetricsDTO
}

struct UFitBrandProductMetricsDTO: Decodable {
    let total: Int
    let draft: Int
    let underReview: Int
    let active: Int
    let rejected: Int
    let archived: Int
}

struct UFitBrandOrderMetricsDTO: Decodable {
    let paid: Int
    let preparing: Int
    let shipped: Int
    let delivered: Int
    let cancelled: Int
    let refunded: Int
}

struct UFitBrandStockMetricsDTO: Decodable {
    let lowStockVariants: Int
}

struct UFitBrandProductsDTO: Decodable {
    let items: [UFitBrandProductDTO]
}

struct UFitBrandProductDTO: Decodable {
    let id: String
    let name: String
    let status: String
    let totalStock: Int
}

struct UFitBrandOrdersDTO: Decodable {
    let items: [UFitBrandOrderDTO]
}

struct UFitBrandOrderDTO: Decodable {
    let id: String
    let orderNumber: String
    let status: String
    let totalAmount: Int
    let currency: String
    let sourceCreatorId: String?
    let createdAt: String?
}
