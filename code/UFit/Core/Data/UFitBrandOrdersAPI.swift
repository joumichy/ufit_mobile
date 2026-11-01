import Foundation

enum UFitBrandOrdersHTTP {
    static let get = "GET"; static let post = "POST"; static let brands = "brands/"; static let orders = "/orders"; static let separator = "/"
    static let shipping = "shipping/shipments/"; static let actions = "/actions"
    static let unauthorized = 401; static let forbidden = 403
    static let limit = "limit"; static let cursor = "cursor"; static let status = "status"; static let pageLimit = 20
}
enum UFitBrandOrderContractError: LocalizedError, Equatable {
    case document, page, draft, stale
    var errorDescription: String? {
        switch self {
        case .document: String(localized: "La commande reçue est incohérente. Actualisez avant de continuer.")
        case .page: String(localized: "Les commandes reçues sont incohérentes. Actualisez pour réessayer.")
        case .draft: String(localized: "Vérifiez les champs indiqués avant l’enregistrement.")
        case .stale: String(localized: "L’expédition a changé. Actualisez la commande avant de continuer.")
        }
    }
}
private enum BrandOrderContract {
    static func money(_ value: Int) -> Bool { (.zero...UFitDecimalInput.maximumInteger).contains(value) }
    static func sum(_ amounts: [Int]) -> Int? {
        var total = Int.zero
        for amount in amounts {
            let next = total.addingReportingOverflow(amount)
            guard !next.overflow else { return nil }; total = next.partialValue
        }
        return total
    }
    static func commands(_ actions: [UFitShipmentAction]) -> Bool {
        Set(actions).count == actions.count && actions.filter(\.isPrimary).count <= UFitShipmentInput.maximumPrimaryActions
    }
}
struct UFitBrandOrderSummaryDTO: Decodable, Identifiable {
    let id: String; let orderNumber: String; let brandId: String
    var status: UFitOrderLifecycle
    let createdAt: UFitTimestamp
    let totalAmount: Int; let currency: String; let itemCount: Int
    @UFitRequiredNullable var shipmentStatus: UFitShipmentLifecycle?
    func validate(brandID: String) throws {
        guard UUID(uuidString: id) != nil, UUID(uuidString: brandId) != nil, brandId == brandID,
              !UFitServerTextInput.trimmed(orderNumber).isEmpty, UFitBrandOrderInput.statuses.contains(status),
              BrandOrderContract.money(totalAmount), itemCount >= .zero,
              currency.range(of: UFitCurrency.codePattern, options: .regularExpression) != nil else { throw UFitBrandOrderContractError.document }
    }
}
struct UFitManagedShipment: Decodable, Identifiable {
    let id: String; let orderId: String; let brandId: String; let version: Int; let status: UFitShipmentLifecycle
    @UFitRequiredNullable var carrier: String?
    @UFitRequiredNullable var trackingNumber: String?
    @UFitRequiredNullable var trackingUrl: String?
    @UFitRequiredNullable var shippedAt: UFitTimestamp?
    @UFitRequiredNullable var deliveredAt: UFitTimestamp?
    @UFitRequiredNullable var incidentReason: String?
    @UFitRequiredNullable var incidentAt: UFitTimestamp?
    func validate(brandID: String, orderID: String, shipmentID: String? = nil) throws {
        guard UUID(uuidString: id) != nil, UUID(uuidString: orderId) != nil, UUID(uuidString: brandId) != nil,
              brandId == brandID, orderId == orderID, shipmentID == nil || shipmentID == id,
              (UFitShipmentInput.initialVersion...UFitShipmentInput.maximumVersion).contains(version),
              (incidentReason == nil) == (incidentAt == nil),
              status != .failed || incidentReason != nil else { throw UFitBrandOrderContractError.document }
        if let trackingUrl, UFitParcelTracking.url(trackingUrl) == nil { throw UFitBrandOrderContractError.document }
        if let incidentReason, !UFitServerTextInput.valid(incidentReason, maximum: UFitShipmentInput.incidentMaximum) { throw UFitBrandOrderContractError.document }
        if status == .shipped || status == .delivered {
            guard let carrier, let trackingNumber, shippedAt != nil,
                  UFitServerTextInput.valid(carrier, maximum: UFitParcelTracking.carrierMaximum),
                  UFitServerTextInput.valid(trackingNumber, maximum: UFitParcelTracking.numberMaximum) else { throw UFitBrandOrderContractError.document }
        }
        if status == .delivered && deliveredAt == nil { throw UFitBrandOrderContractError.document }
    }
}
struct UFitBrandOrderItemDTO: Decodable, Identifiable {
    let id: String; let productId: String; let productVariantId: String; let name: String; let sku: String
    @UFitRequiredNullable var size: String?
    @UFitRequiredNullable var color: String?
    @UFitRequiredNullable var imageUrl: String?
    let quantity: Int; let unitPrice: Int; let totalPrice: Int
    func validate() throws {
        let product = quantity.multipliedReportingOverflow(by: unitPrice)
        guard UUID(uuidString: id) != nil, UUID(uuidString: productId) != nil, UUID(uuidString: productVariantId) != nil,
              !UFitServerTextInput.trimmed(name).isEmpty, !UFitServerTextInput.trimmed(sku).isEmpty, quantity > .zero,
              BrandOrderContract.money(unitPrice), BrandOrderContract.money(totalPrice),
              !product.overflow, product.partialValue == totalPrice else { throw UFitBrandOrderContractError.document }
    }
}
struct UFitBrandOrderDetailDTO: Decodable {
    var summary: UFitBrandOrderSummaryDTO
    let subtotalAmount: Int; let shippingAmount: Int; let taxAmount: Int
    let shippingAddress: UFitShippingAddress
    let items: [UFitBrandOrderItemDTO]
    @UFitRequiredNullable var shipment: UFitManagedShipment?
    var actions: [UFitShipmentAction]
    private enum CodingKeys: String, CodingKey { case subtotalAmount, shippingAmount, taxAmount, shippingAddress, items, shipment, actions }
    init(from decoder: Decoder) throws {
        summary = try UFitBrandOrderSummaryDTO(from: decoder)
        let values = try decoder.container(keyedBy: CodingKeys.self)
        subtotalAmount = try values.decode(Int.self, forKey: .subtotalAmount)
        shippingAmount = try values.decode(Int.self, forKey: .shippingAmount)
        taxAmount = try values.decode(Int.self, forKey: .taxAmount)
        shippingAddress = try values.decode(UFitShippingAddress.self, forKey: .shippingAddress)
        items = try values.decode([UFitBrandOrderItemDTO].self, forKey: .items)
        _shipment = try values.decode(UFitRequiredNullable<UFitManagedShipment>.self, forKey: .shipment)
        actions = try values.decode([UFitShipmentAction].self, forKey: .actions)
    }
    func validate(brandID: String, orderID: String) throws {
        try summary.validate(brandID: brandID)
        guard summary.id == orderID, [subtotalAmount, shippingAmount, taxAmount].allSatisfy(BrandOrderContract.money),
              BrandOrderContract.sum([subtotalAmount, shippingAmount, taxAmount]) == summary.totalAmount,
              BrandOrderContract.sum(items.map(\.totalPrice)) == subtotalAmount,
              BrandOrderContract.sum(items.map(\.quantity)) == summary.itemCount, Set(items.map(\.id)).count == items.count,
              summary.shipmentStatus == shipment?.status, BrandOrderContract.commands(actions), shipment != nil || actions.isEmpty,
              !UFitServerTextInput.trimmed(shippingAddress.fullName).isEmpty, !UFitServerTextInput.trimmed(shippingAddress.line1).isEmpty,
              !UFitServerTextInput.trimmed(shippingAddress.postalCode).isEmpty, !UFitServerTextInput.trimmed(shippingAddress.city).isEmpty,
              shippingAddress.country.range(of: UFitCountry.codePattern, options: .regularExpression) != nil else { throw UFitBrandOrderContractError.document }
        try items.forEach { try $0.validate() }
        try shipment?.validate(brandID: brandID, orderID: orderID)
    }
    mutating func receive(_ result: UFitShipmentResult) {
        summary.status = result.orderStatus; summary.shipmentStatus = result.shipment.status
        shipment = result.shipment; actions = result.actions
    }
}
struct UFitBrandOrdersPage: Decodable {
    let items: [UFitBrandOrderSummaryDTO]
    @UFitRequiredNullable var nextCursor: String?
    func validate(brandID: String) throws {
        guard Set(items.map(\.id)).count == items.count, items.count <= UFitBrandOrdersHTTP.pageLimit,
              nextCursor == nil || nextCursor == items.last?.id else { throw UFitBrandOrderContractError.page }
        try items.forEach { try $0.validate(brandID: brandID) }
    }
}
struct UFitShipmentResult: Decodable {
    let shipment: UFitManagedShipment; let orderStatus: UFitOrderLifecycle; let actions: [UFitShipmentAction]
    func validate(brandID: String, orderID: String, shipmentID: String, previousVersion: Int) throws {
        try shipment.validate(brandID: brandID, orderID: orderID, shipmentID: shipmentID)
        guard previousVersion < UFitShipmentInput.maximumVersion, shipment.version == previousVersion + UFitShipmentInput.versionStep,
              UFitBrandOrderInput.statuses.contains(orderStatus), BrandOrderContract.commands(actions) else { throw UFitBrandOrderContractError.document }
    }
}
struct UFitShipmentActionRequest: Encodable {
    let command: UFitShipmentCommand
    let draft: UFitShipmentFormDraft?
    init(command: UFitShipmentCommand, draft: UFitShipmentFormDraft?) throws {
        guard (UFitShipmentInput.initialVersion..<UFitShipmentInput.maximumVersion).contains(command.expectedVersion),
              command.action.requiresForm == (draft != nil) else { throw UFitBrandOrderContractError.draft }
        if let draft, !UFitShipmentInput.errors(draft, action: command.action).isEmpty { throw UFitBrandOrderContractError.draft }
        self.command = command; self.draft = draft
    }
    private enum CodingKeys: String, CodingKey { case action, expectedVersion, carrier, trackingNumber, trackingUrl, incidentReason }
    func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(command.action, forKey: .action); try values.encode(command.expectedVersion, forKey: .expectedVersion)
        if let draft {
            if command.action == .reportIncident { try values.encode(UFitServerTextInput.trimmed(draft.incidentReason), forKey: .incidentReason) }
            else {
                try values.encode(UFitServerTextInput.trimmed(draft.carrier), forKey: .carrier)
                try values.encode(UFitServerTextInput.trimmed(draft.trackingNumber), forKey: .trackingNumber)
                let link = UFitServerTextInput.trimmed(draft.trackingURL)
                if link.isEmpty { try values.encodeNil(forKey: .trackingUrl) } else { try values.encode(link, forKey: .trackingUrl) }
            }
        }
    }
}
extension UFitAPIClient {
    func fetchBrandOrders(brandID: String, status: UFitOrderLifecycle?, cursor: String?) async throws -> UFitBrandOrdersPage {
        var query = [URLQueryItem(name: UFitBrandOrdersHTTP.limit, value: String(UFitBrandOrdersHTTP.pageLimit))]
        if let status { query.append(.init(name: UFitBrandOrdersHTTP.status, value: status.rawValue)) }
        if let cursor { query.append(.init(name: UFitBrandOrdersHTTP.cursor, value: cursor)) }
        do {
            let result: UFitBrandOrdersPage = try await send(UFitBrandOrdersHTTP.get, path: UFitBrandOrdersHTTP.brands + brandID + UFitBrandOrdersHTTP.orders, query: query, requiresAuth: true)
            try result.validate(brandID: brandID); return result
        } catch is DecodingError { throw UFitBrandOrderContractError.page }
    }
    func fetchBrandOrder(brandID: String, orderID: String) async throws -> UFitBrandOrderDetailDTO {
        do {
            let result: UFitBrandOrderDetailDTO = try await send(UFitBrandOrdersHTTP.get, path: UFitBrandOrdersHTTP.brands + brandID + UFitBrandOrdersHTTP.orders + UFitBrandOrdersHTTP.separator + orderID, requiresAuth: true)
            try result.validate(brandID: brandID, orderID: orderID); return result
        } catch is DecodingError { throw UFitBrandOrderContractError.document }
    }
    func performShipment(brandID: String, orderID: String, shipmentID: String, command: UFitShipmentCommand, draft: UFitShipmentFormDraft? = nil) async throws -> UFitShipmentResult {
        let body = try UFitShipmentActionRequest(command: command, draft: draft)
        do {
            let result: UFitShipmentResult = try await send(UFitBrandOrdersHTTP.post, path: UFitBrandOrdersHTTP.shipping + shipmentID + UFitBrandOrdersHTTP.actions, body: body, requiresAuth: true)
            try result.validate(brandID: brandID, orderID: orderID, shipmentID: shipmentID, previousVersion: command.expectedVersion); return result
        } catch is DecodingError { throw UFitBrandOrderContractError.document }
    }
}
private enum UFitBrandOrderFailureCode: String {
    case changed = "shipment_version_changed", state = "order_shipping_state_changed", access = "brand_management_access_required"
    case orderMissing = "brand_order_not_found", shipmentMissing = "shipment_not_found", persisted = "brand_order_persisted_invalid", cursor = "brand_order_cursor_invalid"
}
extension UFitAPIError {
    var brandOrderFailureDescription: String? {
        guard case .requestFailed(_, _, let raw) = self, let raw, let code = UFitBrandOrderFailureCode(rawValue: raw) else { return nil }
        switch code {
        case .changed: return String(localized: "L’expédition a changé. Actualisez la commande avant de recommencer.")
        case .state: return String(localized: "Cette action n’est plus disponible. Actualisez la commande.")
        case .access: return String(localized: "Votre accès à cette marque a changé. Revenez aux espaces et actualisez.")
        case .orderMissing, .shipmentMissing: return String(localized: "Cette commande ou son expédition n’est plus disponible. Actualisez la liste.")
        case .persisted: return UFitBrandOrderContractError.document.localizedDescription
        case .cursor: return String(localized: "La liste des commandes a changé. Actualisez-la avant de continuer.")
        }
    }
    var losesBrandOrderAccess: Bool {
        switch self {
        case .authenticationRequired: true
        case .requestFailed(let status, _, _): status == UFitBrandOrdersHTTP.unauthorized || status == UFitBrandOrdersHTTP.forbidden
        default: false
        }
    }
    var isShipmentConflict: Bool {
        guard case .requestFailed(_, _, let raw) = self, let raw, let code = UFitBrandOrderFailureCode(rawValue: raw) else { return false }
        return code == .changed || code == .state
    }
}
