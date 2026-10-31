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
    case authenticationRequired, invalidURL, emptyResponse
    case requestFailed(statusCode: Int, message: String, code: String? = nil)
    var isCartConflict: Bool {
        guard case .requestFailed(_, _, let code) = self else { return false }
        return code == Code.brand || code == Code.currency
    }
    private enum Code {
        static let brand = "cart_brand_conflict"
        static let currency = "cart_currency_conflict"
        static let stock = "cart_insufficient_stock"
        static let cancellationUnavailable = "order_cancellation_unavailable"
        static let cancellationChanged = "order_cancellation_changed"
        static let paymentUnavailable = "order_payment_unavailable"
        static let connectSetup = "connect_platform_setup_required"
        static let connectCountry = "connect_country_immutable"
        static let connectRecipient = "connect_recipient_incomplete"
        static let connectOwner = "connect_owner_required"
        static let refundAttention = "order_refund_requires_attention"
    }
    var errorDescription: String? {
        switch self {
        case .authenticationRequired: String(localized: "Connectez-vous pour continuer.")
        case .invalidURL, .emptyResponse: String(localized: "Le service est momentanément indisponible.")
        case .requestFailed(let status, _, let code):
            if code == Code.brand || code == Code.currency { String(localized: "Votre panier contient une autre marque ou devise.") }
            else if code == "checkout_quote_changed" || code == "cart_changed" { String(localized: "Le panier ou les frais ont changé. Vérifiez le nouveau montant.") }
            else if code == "shipping_unavailable" { String(localized: "La marque ne livre pas dans ce pays pour cette devise.") }
            else if code == "brand_policy_missing" || code == "brand_policy_invalid" { String(localized: "Les conditions de livraison de la marque ne sont pas encore disponibles.") }
            else if code == Code.cancellationUnavailable { String(localized: "Cette commande ne peut plus être annulée.") }
            else if code == Code.cancellationChanged { String(localized: "L’état de la commande a changé. Actualisez avant de réessayer.") }
            else if code == Code.paymentUnavailable { String(localized: "Cette commande n’accepte plus de paiement. Actualisez son statut.") }
            else if code == Code.connectSetup { String(localized: "La plateforme doit terminer sa configuration Stripe Connect. Votre compte n’est pas encore activé.") }
            else if code == Code.connectCountry { String(localized: "Le pays de ce compte Stripe ne peut plus être modifié.") }
            else if code == Code.connectRecipient { String(localized: "La marque ou le créateur doit terminer sa configuration Stripe avant cet achat.") }
            else if code == Code.connectOwner { String(localized: "Seul le propriétaire peut configurer ce compte Stripe.") }
            else if code == Code.refundAttention { String(localized: "Le remboursement nécessite une vérification. Votre demande d’annulation reste enregistrée.") }
            else if code == Code.stock { String(localized: "La quantité demandée n’est plus disponible.") }
            else if status == 401 { String(localized: "Votre session a expiré. Reconnectez-vous.") }
            else if status == 403 { String(localized: "Votre compte ne peut pas effectuer cette action.") }
            else if status == 404 { String(localized: "Cet élément n’est plus disponible.") }
            else { String(localized: "L’action a échoué. Actualisez et réessayez.") }
        }
    }
}

private struct UFitServerFailure: Decodable {
    let code: String?
    let message: Message?
    enum Message: Decodable {
        case text(String), fields([String])
        init(from decoder: Decoder) throws {
            let value = try decoder.singleValueContainer()
            if let text = try? value.decode(String.self) { self = .text(text) }
            else { self = .fields(try value.decode([String].self)) }
        }
        var text: String {
            switch self { case .text(let text): text; case .fields(let fields): fields.joined(separator: "\n") }
        }
    }
}

struct UFitAPIClient {
    let configuration: UFitAPIConfiguration
    private let session: URLSession
    private let tokenProvider: (@Sendable () async throws -> String?)?
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    init(configuration: UFitAPIConfiguration = .live(), session: URLSession = .shared, tokenProvider: (@Sendable () async throws -> String?)? = nil) {
        self.configuration = configuration
        self.session = session
        self.tokenProvider = tokenProvider
    }

    func updateProfile(name: String) async throws -> UFitCurrentUser {
        struct ProfilePatch: Encodable { let displayName: String }
        return try await send("PATCH", path: "me", body: ProfilePatch(displayName: name), requiresAuth: true)
    }

    func fetchSavedOutfits() async throws -> UFitSavedReferencesDTO {
        try await send("GET", path: "me/saved-outfits", requiresAuth: true)
    }

    func fetchCurrentUser() async throws -> UFitCurrentUser {
        try await send("GET", path: "me", requiresAuth: true)
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

    func checkout(_ body: UFitCheckoutRequest) async throws -> UFitPaymentIntentDTO {
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

    func send<Response: Decodable, Body: Encodable>(
        _ method: String,
        path: String,
        query: [URLQueryItem] = [],
        body: Body,
        requiresAuth: Bool = false
    ) async throws -> Response {
        try await send(method, path: path, query: query, bodyData: encoder.encode(body), requiresAuth: requiresAuth)
    }

    func send<Response: Decodable>(
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
        let token: String?
        if let tokenProvider {
            token = requiresAuth ? try await tokenProvider() : nil
        } else { token = configuration.bearerToken }
        if requiresAuth, token == nil {
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
        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw UFitAPIError.emptyResponse
        }
        guard 200..<300 ~= httpResponse.statusCode else {
            let failure = try? decoder.decode(UFitServerFailure.self, from: data)
            throw UFitAPIError.requestFailed(statusCode: httpResponse.statusCode, message: failure?.message?.text ?? String(), code: failure?.code)
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
    let prices: [UFitProductPriceDTO]
    let author: OutfitAuthor?
    let creatorId: String?
    let brandId: String?
    let publishedAt: String?
}

struct UFitOutfitDetailDTO: Decodable {
    let id: String
    let title: String
    let coverImageUrl: String
    let prices: [UFitProductPriceDTO]
    let author: OutfitAuthor?
    let creatorId: String?
    let brandId: String?
    let publishedAt: String?
    let description: String
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
    let description: String
    let category: String
    let images: [UFitProductImageDTO]
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

struct UFitSavedReferencesDTO: Decodable {
    struct Item: Decodable { let id: String; let savedAt: String }
    let items: [Item]
}

struct UFitSavedActionDTO: Decodable {
    let saved: Bool?
}

struct UFitCartDTO: Decodable {
    let id: String
    let status: String
    let brandId: String?
    let subtotalAmount: Int
    let currency: String
    let items: [UFitCartLineDTO]
}

struct UFitAddCartItemRequest: Encodable {
    let productVariantId: String
    let quantity: Int
    let sourceOutfitId: String?
}

struct UFitCheckoutRequest: Encodable {
    let requestId: String
    let quoteFingerprint: String
    let shippingAddress: UFitShippingAddress
}

struct UFitPaymentIntentDTO: Decodable {
    let orderId: String
    let paymentIntentId: String
    let clientSecret: String
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
