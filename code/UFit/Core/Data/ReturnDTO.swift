import Foundation

enum UFitReturnContractError: LocalizedError {
    case document, draft, page
    var errorDescription: String? {
        switch self {
        case .document: String(localized: "Le retour reçu est incohérent. Actualisez le dossier avant de continuer.")
        case .draft: String(localized: "Vérifiez la sélection et les champs indiqués avant de continuer.")
        case .page: String(localized: "La liste des retours a changé. Actualisez-la pour continuer.")
        }
    }
}
enum UFitReturnScope: Equatable {
    case customer(orderID: String), brand(brandID: String), administrator
    var role: UFitReturnRole {
        switch self { case .customer: .customer; case .brand: .brand; case .administrator: .administrator }
    }
    func contains(orderID: String, brandID: String) -> Bool {
        switch self {
        case .customer(let expected): expected == orderID
        case .brand(let expected): expected == brandID
        case .administrator: true
        }
    }
}
enum UFitReturnContract {
    static let single = 1
    static func money(_ value: Int) -> Bool { (.zero...UFitDecimalInput.maximumInteger).contains(value) }
    static func quantity(_ value: Int) -> Bool { (single...UFitDecimalInput.maximumInteger).contains(value) }
    static func currency(_ value: String) -> Bool { value.range(of: UFitCurrency.codePattern, options: .regularExpression) != nil }
    static func sum(_ values: [Int]) -> Int? {
        var result = Int.zero
        for value in values {
            let next = result.addingReportingOverflow(value)
            guard !next.overflow else { return nil }; result = next.partialValue
        }
        return result
    }
    static func nonempty(_ value: String) -> Bool { !UFitServerTextInput.trimmed(value).isEmpty }
    static func validItems(_ ids: [String]) -> Bool {
        (single...UFitReturnInput.maximumItems).contains(ids.count) && ids.allSatisfy { UUID(uuidString: $0) != nil } && Set(ids).count == ids.count
    }
}
struct UFitReturnSummaryDTO: Decodable, Identifiable {
    let id: String; let orderId: String; let brandId: String; let orderNumber: String
    let version: Int; let status: UFitReturnStatus; let requestedAt: UFitTimestamp
    let itemCount: Int; let totalAmount: Int; let currency: String
    func validate(scope: UFitReturnScope) throws {
        guard [id, orderId, brandId].allSatisfy({ UUID(uuidString: $0) != nil }), scope.contains(orderID: orderId, brandID: brandId),
              UFitReturnContract.nonempty(orderNumber), (UFitReturnInput.initialVersion...UFitReturnInput.maximumVersion).contains(version),
              itemCount > .zero, UFitReturnContract.money(totalAmount), UFitReturnContract.currency(currency) else { throw UFitReturnContractError.document }
    }
}
struct UFitReturnAmountsDTO: Decodable {
    let refundPolicyCode: UFitRefundPolicy
    let merchandiseAmount: Int; let taxAmount: Int; let shippingAmount: Int; let totalAmount: Int; let completesOrder: Bool
    func validate() throws {
        guard [merchandiseAmount, taxAmount, shippingAmount, totalAmount].allSatisfy(UFitReturnContract.money),
              UFitReturnContract.sum([merchandiseAmount, taxAmount, shippingAmount]) == totalAmount,
              completesOrder || shippingAmount == .zero else { throw UFitReturnContractError.document }
    }
}
struct UFitReturnItemDTO: Decodable, Identifiable {
    let orderItemId: String; let quantity: Int; let orderedQuantity: Int
    let name: String; let sku: String
    @UFitRequiredNullable var size: String?
    @UFitRequiredNullable var color: String?
    @UFitRequiredNullable var imageUrl: String?
    let unitPrice: Int; let merchandiseAmount: Int
    @UFitRequiredNullable var restockQuantity: Int?
    var id: String { orderItemId }
    func validate() throws {
        let product = unitPrice.multipliedReportingOverflow(by: quantity)
        guard UUID(uuidString: id) != nil, UFitReturnContract.quantity(quantity), UFitReturnContract.quantity(orderedQuantity), quantity <= orderedQuantity,
              UFitReturnContract.nonempty(name), UFitReturnContract.nonempty(sku), UFitReturnContract.money(unitPrice), UFitReturnContract.money(merchandiseAmount),
              !product.overflow, product.partialValue == merchandiseAmount else { throw UFitReturnContractError.document }
        if let restockQuantity, !(.zero...quantity).contains(restockQuantity) { throw UFitReturnContractError.document }
    }
}
enum UFitReturnDecision: String, Decodable { case approved, rejected }
struct UFitReturnDecisionDTO: Decodable {
    let decision: UFitReturnDecision
    @UFitRequiredNullable var reason: String?
    @UFitRequiredNullable var instructions: String?
    let at: UFitTimestamp
    func validate(administrator: Bool) throws {
        if let reason, !UFitServerTextInput.valid(reason, maximum: UFitReturnInput.reasonMaximum) { throw UFitReturnContractError.document }
        if let instructions, !UFitServerTextInput.valid(instructions, maximum: UFitReturnInput.instructionsMaximum) { throw UFitReturnContractError.document }
        guard (decision == .approved ? instructions != nil : reason != nil && instructions == nil),
              !administrator || reason != nil else { throw UFitReturnContractError.document }
    }
}
struct UFitReturnDisputeDTO: Decodable { let reason: String; let at: UFitTimestamp }
struct UFitReturnTrackingDTO: Decodable {
    let carrier: String; let trackingNumber: String
    @UFitRequiredNullable var trackingUrl: String?
    let sentAt: UFitTimestamp
    func validate() throws {
        guard UFitServerTextInput.valid(carrier, maximum: UFitParcelTracking.carrierMaximum),
              UFitServerTextInput.valid(trackingNumber, maximum: UFitParcelTracking.numberMaximum),
              trackingUrl == nil || UFitParcelTracking.url(trackingUrl!) != nil else { throw UFitReturnContractError.document }
    }
}
struct UFitReturnRestockDTO: Codable { let orderItemId: String; let restockQuantity: Int }
struct UFitReturnReceptionDTO: Decodable { let at: UFitTimestamp; let items: [UFitReturnRestockDTO] }
enum UFitReturnRefundState: String, Decodable { case queued, pending, succeeded, failed, blocked }
enum UFitReturnProviderState: String, Decodable { case pending, requiresAction = "requires_action", succeeded, failed, canceled }
struct UFitReturnRefundDTO: Decodable {
    let attemptNumber: Int; let amount: Int; let state: UFitReturnRefundState
    @UFitRequiredNullable var providerStatus: UFitReturnProviderState?
    let updatedAt: UFitTimestamp
    func validate(status: UFitReturnStatus) throws {
        switch state {
        case .queued:
            guard status == .refundPending, providerStatus == nil else { throw UFitReturnContractError.document }
        case .pending:
            guard status == .refundPending, providerStatus == .pending || providerStatus == .requiresAction else { throw UFitReturnContractError.document }
        case .failed:
            guard status == .refundFailed, providerStatus == .failed || providerStatus == .canceled else { throw UFitReturnContractError.document }
        case .blocked:
            guard status == .refundFailed, amount > .zero, providerStatus == nil else { throw UFitReturnContractError.document }
        case .succeeded:
            guard status == .refunded, amount == .zero ? providerStatus == nil : providerStatus == .succeeded else { throw UFitReturnContractError.document }
        }
    }
}
struct UFitReturnDetailDTO: Decodable, Identifiable {
    let id: String; let orderId: String; let brandId: String; let version: Int; let status: UFitReturnStatus
    let reason: String; let items: [UFitReturnItemDTO]; let amounts: UFitReturnAmountsDTO
    let requestedAt: UFitTimestamp; let deadline: UFitTimestamp; let updatedAt: UFitTimestamp
    @UFitRequiredNullable var refundedAt: UFitTimestamp?
    @UFitRequiredNullable var brandDecision: UFitReturnDecisionDTO?
    @UFitRequiredNullable var dispute: UFitReturnDisputeDTO?
    @UFitRequiredNullable var adminDecision: UFitReturnDecisionDTO?
    @UFitRequiredNullable var tracking: UFitReturnTrackingDTO?
    @UFitRequiredNullable var reception: UFitReturnReceptionDTO?
    let orderNumber: String; let currency: String; let returnPolicy: String
    @UFitRequiredNullable var refund: UFitReturnRefundDTO?
    let actions: [UFitReturnAction]
    var summary: UFitReturnSummaryDTO {
        .init(id: id, orderId: orderId, brandId: brandId, orderNumber: orderNumber, version: version, status: status, requestedAt: requestedAt,
              itemCount: items.reduce(.zero) { $0 + $1.quantity }, totalAmount: amounts.totalAmount, currency: currency)
    }
    func validate(scope: UFitReturnScope, expectedID: String? = nil) throws {
        guard UFitReturnContract.validItems(items.map(\.id)) else { throw UFitReturnContractError.document }
        try items.forEach { try $0.validate() }; try summary.validate(scope: scope); try amounts.validate()
        guard expectedID == nil || expectedID == id, UFitReturnContract.validItems(items.map(\.id)),
              UFitServerTextInput.valid(reason, maximum: UFitReturnInput.reasonMaximum), UFitReturnContract.nonempty(returnPolicy),
              UFitReturnContract.sum(items.map(\.merchandiseAmount)) == amounts.merchandiseAmount,
              updatedAt.value >= requestedAt.value, deadline.value >= requestedAt.value,
              Set(actions).count == actions.count, actions.filter(\.isPrimary).count <= UFitReturnContract.single,
              version < UFitReturnInput.maximumVersion || actions.isEmpty else { throw UFitReturnContractError.document }
        try brandDecision?.validate(administrator: false); try adminDecision?.validate(administrator: true); try tracking?.validate()
        if let dispute, !UFitServerTextInput.valid(dispute.reason, maximum: UFitReturnInput.reasonMaximum) { throw UFitReturnContractError.document }
        if let reception {
            guard UFitReturnContract.validItems(reception.items.map(\.orderItemId)), reception.items.count == items.count else { throw UFitReturnContractError.document }
            let choices = Dictionary(uniqueKeysWithValues: reception.items.map { ($0.orderItemId, $0.restockQuantity) })
            guard items.allSatisfy({ item in choices[item.id] == item.restockQuantity && item.restockQuantity != nil }) else { throw UFitReturnContractError.document }
        } else if items.contains(where: { $0.restockQuantity != nil }) { throw UFitReturnContractError.document }
        if let refund {
            guard UFitReturnContract.quantity(refund.attemptNumber), refund.amount == amounts.totalAmount, reception != nil else { throw UFitReturnContractError.document }
            try refund.validate(status: status)
        }
        if status == .refunded {
            guard refundedAt != nil, reception != nil, refund?.state == .succeeded,
                  (amounts.totalAmount == .zero ? refund?.providerStatus == nil : refund?.providerStatus == .succeeded), actions.isEmpty else { throw UFitReturnContractError.document }
        } else if refundedAt != nil { throw UFitReturnContractError.document }
        if status == .refundPending || status == .refundFailed {
            guard reception != nil, refund != nil else { throw UFitReturnContractError.document }
        }
        if ![.refundPending, .refundFailed, .refunded].contains(status), reception != nil || refund != nil { throw UFitReturnContractError.document }
        if status == .inTransit && tracking == nil { throw UFitReturnContractError.document }
        if status == .disputed && dispute == nil { throw UFitReturnContractError.document }
        if status == .closed && adminDecision?.decision != .rejected { throw UFitReturnContractError.document }
        let allowed = allowedActions(scope.role)
        guard actions.allSatisfy(allowed.contains) else { throw UFitReturnContractError.document }
    }
    private func allowedActions(_ role: UFitReturnRole) -> Set<UFitReturnAction> {
        switch role {
        case .customer:
            switch status {
            case .requested: return [.withdraw]
            case .approved: return [.send, .withdraw]
            case .rejected: return [.dispute, .withdraw]
            case .inTransit: return [.updateTracking]
            default: return []
            }
        case .brand:
            switch status {
            case .requested: return [.approve, .reject]
            case .approved, .inTransit: return [.receive]
            case .refundFailed: return refund?.providerStatus == .canceled ? [.retryRefund] : []
            default: return []
            }
        case .administrator:
            switch status {
            case .disputed: return [.arbitrateApprove, .arbitrateReject]
            case .refundFailed: return refund?.providerStatus == .canceled ? [.retryRefund] : []
            default: return []
            }
        }
    }
}
struct UFitReturnsPageDTO: Decodable {
    let items: [UFitReturnSummaryDTO]
    @UFitRequiredNullable var nextCursor: String?
    func validate(scope: UFitReturnScope, cursor: String?, status: UFitReturnStatus?) throws {
        guard items.count <= UFitReturnsHTTP.pageLimit, Set(items.map(\.id)).count == items.count,
              nextCursor == nil || (nextCursor == items.last?.id && nextCursor != cursor),
              status == nil || items.allSatisfy({ $0.status == status }) else { throw UFitReturnContractError.page }
        try items.forEach { try $0.validate(scope: scope) }
    }
}
enum UFitReturnUnavailable: String, Decodable {
    case notDelivered = "not_delivered", missingTerms = "missing_terms", windowClosed = "window_closed", openReturn = "open_return", allReturned = "all_returned"
    var label: String {
        switch self {
        case .notDelivered: String(localized: "Un retour pourra être demandé après la livraison.")
        case .missingTerms: String(localized: "Les conditions de retour de cette commande ne sont pas disponibles. Contactez le support.")
        case .windowClosed: String(localized: "Le délai de retour est terminé ou cette commande n’est pas éligible au retour.")
        case .openReturn: String(localized: "Un retour est déjà en cours pour cette commande. Ouvrez son dossier pour continuer.")
        case .allReturned: String(localized: "Toutes les pièces de cette commande ont déjà été retournées.")
        }
    }
}
struct UFitReturnOptionsItemDTO: Decodable, Identifiable {
    let id: String; let productId: String; let productVariantId: String; let name: String; let sku: String
    @UFitRequiredNullable var size: String?
    @UFitRequiredNullable var color: String?
    @UFitRequiredNullable var imageUrl: String?
    let quantity: Int; let unitPrice: Int; let totalPrice: Int; let availableQuantity: Int
    func validate() throws {
        let product = quantity.multipliedReportingOverflow(by: unitPrice)
        guard [id, productId, productVariantId].allSatisfy({ UUID(uuidString: $0) != nil }), UFitReturnContract.quantity(quantity),
              UFitReturnContract.nonempty(name), UFitReturnContract.nonempty(sku), UFitReturnContract.money(unitPrice), UFitReturnContract.money(totalPrice),
              !product.overflow, product.partialValue == totalPrice, (.zero...quantity).contains(availableQuantity) else { throw UFitReturnContractError.document }
    }
}
struct UFitReturnOptionsDTO: Decodable {
    let orderId: String; let currency: String
    @UFitRequiredNullable var returnPolicy: String?
    let refundPolicyCode: UFitRefundPolicy
    @UFitRequiredNullable var deadline: UFitTimestamp?
    let canRequest: Bool
    @UFitRequiredNullable var unavailableReason: UFitReturnUnavailable?
    @UFitRequiredNullable var openReturnId: String?
    let items: [UFitReturnOptionsItemDTO]
    func validate(orderID: String) throws {
        guard self.orderId == orderID, UUID(uuidString: orderID) != nil, UFitReturnContract.currency(currency),
              !items.isEmpty, Set(items.map(\.id)).count == items.count, canRequest == (unavailableReason == nil),
              (openReturnId != nil) == (unavailableReason == .openReturn) else { throw UFitReturnContractError.document }
        try items.forEach { try $0.validate() }
        if let openReturnId, UUID(uuidString: openReturnId) == nil { throw UFitReturnContractError.document }
        if canRequest && (deadline == nil || returnPolicy == nil || !items.contains(where: { $0.availableQuantity > .zero })) { throw UFitReturnContractError.document }
    }
}
struct UFitReturnQuoteDTO: Decodable {
    let orderId: String; let currency: String; let deadline: UFitTimestamp; let amounts: UFitReturnAmountsDTO; let fingerprint: String
    func validate(orderID: String, options: UFitReturnOptionsDTO) throws {
        try amounts.validate()
        guard orderId == orderID, currency == options.currency, deadline == options.deadline,
              fingerprint.range(of: UFitReturnInput.fingerprintPattern, options: .regularExpression) != nil else { throw UFitReturnContractError.document }
    }
}
