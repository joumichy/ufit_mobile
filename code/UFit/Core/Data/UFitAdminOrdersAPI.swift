import Foundation

enum UFitAdminOrdersHTTP {
    static let get = "GET", root = "admin/orders", separator = "/", returns = "/returns"
    static let limit = "limit", cursor = "cursor", revision = "revision", search = "search", status = "status", currency = "currency", shipmentStatus = "shipmentStatus"
    static let pageSize = 20, searchMaximum = 120
    static let revisionPattern = "^[a-f0-9]{32}$"
    static let unauthorized = 401, forbidden = 403, missing = 404, changed = 409
    static let changedCode = "admin_orders_changed"
    static func id(_ id: String) throws -> String {
        guard UUID(uuidString: id) != nil, id == id.lowercased() else { throw UFitAdminOrdersFailure.document }
        return root + separator + id
    }
}
enum UFitAdminOrdersFailure: LocalizedError {
    case document, page
    var errorDescription: String? {
        switch self {
        case .document: String(localized: "Les informations de commande reçues sont incohérentes. Actualisez avant de continuer.")
        case .page: String(localized: "La liste de commandes reçue est incohérente. Actualisez pour continuer.")
        }
    }
}
struct UFitAdminOrderSummary: Decodable, Identifiable {
    struct Brand: Decodable { let id: String; let name: String }
    let id: String; let orderNumber: String; let brand: Brand; let status: UFitOrderLifecycle
    let createdAt: UFitTimestamp; let totalAmount: Int; let currency: String; let itemCount: Int
    @UFitRequiredNullable var shipmentStatus: UFitShipmentLifecycle?
    let paymentRecorded: Bool; let returnCount: Int
    func validate() throws {
        guard [id, brand.id].allSatisfy({ UUID(uuidString: $0) != nil }), !UFitServerTextInput.trimmed(orderNumber).isEmpty,
              !UFitServerTextInput.trimmed(brand.name).isEmpty, UFitReturnContract.money(totalAmount), UFitReturnContract.currency(currency),
              itemCount >= .zero, returnCount >= .zero else { throw UFitAdminOrdersFailure.document }
    }
}
struct UFitAdminOrderPage: Decodable {
    let items: [UFitAdminOrderSummary]
    @UFitRequiredNullable var nextCursor: String?
    let revision: String; let totalCount: Int; let asOf: UFitTimestamp; let currencies: [String]
    func validate(query: UFitAdminOrderQuery, cursor: String?, expectedRevision: String?) throws {
        try items.forEach { try $0.validate() }
        guard items.count <= UFitAdminOrdersHTTP.pageSize, totalCount >= items.count, Set(items.map(\.id)).count == items.count,
              revision.range(of: UFitAdminOrdersHTTP.revisionPattern, options: .regularExpression) != nil,
              expectedRevision == nil || revision == expectedRevision, Set(currencies).count == currencies.count,
              currencies.allSatisfy(UFitReturnContract.currency),
              items.allSatisfy({ $0.id != cursor && (query.status == nil || $0.status == query.status) &&
                  (query.currency == nil || $0.currency == query.currency) && (query.shipmentStatus == nil || $0.shipmentStatus == query.shipmentStatus) }),
              nextCursor == nil || (items.count == UFitAdminOrdersHTTP.pageSize && nextCursor == items.last?.id) else { throw UFitAdminOrdersFailure.page }
    }
}
struct UFitAdminOrderPayment: Decodable, Identifiable {
    enum Status: String, Decodable { case succeeded, refunded
        var label: String { self == .succeeded ? UFitAdminOrdersCopy.paymentSucceeded : UFitAdminOrdersCopy.paymentRefunded }
    }
    enum Provider: String, Decodable { case stripe
        var label: String { Copy.stripe }
        private enum Copy { static let stripe = "Stripe" }
    }
    let id: String; let provider: Provider; let status: Status; let amount: Int; let currency: String
    @UFitRequiredNullable var providerPaymentIntentId: String?
    let createdAt: UFitTimestamp; let updatedAt: UFitTimestamp
}
struct UFitAdminOrderDetail: Decodable {
    let order: UFitOrderDTO; let brand: UFitAdminOrderSummary.Brand; let payments: [UFitAdminOrderPayment]; let returnCount: Int; let asOf: UFitTimestamp
    func validate(id: String) throws {
        guard order.id == id, UUID(uuidString: id) != nil, brand.id == order.brandId, !UFitServerTextInput.trimmed(brand.name).isEmpty,
              !UFitServerTextInput.trimmed(order.orderNumber).isEmpty, UFitTimestamp(isoString: order.createdAt) != nil, returnCount >= .zero,
              [order.subtotalAmount, order.shippingAmount, order.taxAmount, order.totalAmount].allSatisfy(UFitReturnContract.money),
              UFitReturnContract.sum([order.subtotalAmount, order.shippingAmount, order.taxAmount]) == order.totalAmount,
              UFitReturnContract.currency(order.currency), !order.items.isEmpty, Set(order.items.map(\.id)).count == order.items.count,
              order.items.allSatisfy({ item in
                  let multiplied = item.unitPrice.multipliedReportingOverflow(by: item.quantity)
                  return [item.id, item.productId, item.productVariantId].allSatisfy({ UUID(uuidString: $0) != nil }) &&
                      !UFitServerTextInput.trimmed(item.productSnapshot.name).isEmpty && item.quantity > .zero && !multiplied.overflow &&
                      multiplied.partialValue == item.totalPrice && UFitReturnContract.money(item.totalPrice)
              }),
              UFitReturnContract.sum(order.items.map(\.totalPrice)) == order.subtotalAmount,
              Set(payments.map(\.id)).count == payments.count,
              payments.allSatisfy({ UUID(uuidString: $0.id) != nil && $0.amount == order.totalAmount && $0.currency == order.currency && $0.updatedAt.value >= $0.createdAt.value })
        else { throw UFitAdminOrdersFailure.document }
        try order.cancellation?.validateSettlement(amount: order.totalAmount, currency: order.currency)
    }
}
extension UFitAPIClient {
    func fetchAdminOrders(query: UFitAdminOrderQuery, cursor: String?, revision: String?) async throws -> UFitAdminOrderPage {
        guard query.search.utf16.count <= UFitAdminOrdersHTTP.searchMaximum, (cursor == nil) == (revision == nil) else { throw UFitAdminOrdersFailure.page }
        var parameters = [URLQueryItem(name: UFitAdminOrdersHTTP.limit, value: String(UFitAdminOrdersHTTP.pageSize))]
        if !query.search.isEmpty { parameters.append(.init(name: UFitAdminOrdersHTTP.search, value: query.search)) }
        if let status = query.status { parameters.append(.init(name: UFitAdminOrdersHTTP.status, value: status.rawValue)) }
        if let currency = query.currency { parameters.append(.init(name: UFitAdminOrdersHTTP.currency, value: currency)) }
        if let shipment = query.shipmentStatus { parameters.append(.init(name: UFitAdminOrdersHTTP.shipmentStatus, value: shipment.rawValue)) }
        if let cursor { parameters.append(.init(name: UFitAdminOrdersHTTP.cursor, value: cursor)) }
        if let revision { parameters.append(.init(name: UFitAdminOrdersHTTP.revision, value: revision)) }
        let result: UFitAdminOrderPage = try await send(UFitAdminOrdersHTTP.get, path: UFitAdminOrdersHTTP.root, query: parameters, requiresAuth: true)
        try result.validate(query: query, cursor: cursor, expectedRevision: revision); return result
    }
    func fetchAdminOrder(id: String) async throws -> UFitAdminOrderDetail {
        let result: UFitAdminOrderDetail = try await send(UFitAdminOrdersHTTP.get, path: UFitAdminOrdersHTTP.id(id), requiresAuth: true)
        try result.validate(id: id); return result
    }
    func fetchAdminOrderReturns(id: String, cursor: String?) async throws -> UFitReturnsPageDTO {
        var query = [URLQueryItem(name: UFitAdminOrdersHTTP.limit, value: String(UFitAdminOrdersHTTP.pageSize))]
        if let cursor { query.append(.init(name: UFitAdminOrdersHTTP.cursor, value: cursor)) }
        let result: UFitReturnsPageDTO = try await send(UFitAdminOrdersHTTP.get, path: UFitAdminOrdersHTTP.id(id) + UFitAdminOrdersHTTP.returns, query: query, requiresAuth: true)
        try result.validate(scope: .administrator, cursor: cursor, status: nil)
        guard result.items.allSatisfy({ $0.orderId == id && $0.id != cursor }) else { throw UFitReturnContractError.page }
        return result
    }
}
