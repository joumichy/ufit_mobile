import Foundation

enum UFitReturnsHTTP {
    static let get = "GET"; static let post = "POST"
    static let orders = "orders/"; static let brands = "brands/"; static let administrator = "admin/returns"
    static let returns = "/returns"; static let separator = "/"; static let actions = "/actions"; static let options = "/options"; static let preview = "/preview"
    static let limit = "limit"; static let cursor = "cursor"; static let status = "status"; static let pageLimit = 20
    static let unauthorized = 401; static let forbidden = 403
}
extension UFitReturnScope {
    var path: String {
        get throws {
            switch self {
            case .customer(let id):
                guard UUID(uuidString: id) != nil else { throw UFitReturnContractError.draft }
                return UFitReturnsHTTP.orders + id + UFitReturnsHTTP.returns
            case .brand(let id):
                guard UUID(uuidString: id) != nil else { throw UFitReturnContractError.draft }
                return UFitReturnsHTTP.brands + id + UFitReturnsHTTP.returns
            case .administrator: return UFitReturnsHTTP.administrator
            }
        }
    }
}
struct UFitReturnSelectionItem: Codable, Equatable { let orderItemId: String; let quantity: Int }
struct UFitReturnSelection: Encodable {
    let items: [UFitReturnSelectionItem]
    init(draft: UFitReturnCreationDraft, options: UFitReturnOptionsDTO) throws {
        let available = Dictionary(uniqueKeysWithValues: options.items.map { ($0.id, $0.availableQuantity) })
        guard draft.quantities.allSatisfy({ id, quantity in available[id].map { (.zero...$0).contains(quantity) } == true }) else { throw UFitReturnContractError.draft }
        items = draft.quantities.filter { $0.value > .zero }.map { .init(orderItemId: $0.key, quantity: $0.value) }.sorted { $0.orderItemId < $1.orderItemId }
        guard UFitReturnContract.validItems(items.map(\.orderItemId)) else { throw UFitReturnContractError.draft }
    }
}
struct UFitReturnCreationRequest: Codable, Equatable {
    let requestId: String; let reason: String; let quoteFingerprint: String; let items: [UFitReturnSelectionItem]
    init(requestID: String, draft: UFitReturnCreationDraft, quote: UFitReturnQuoteDTO, options: UFitReturnOptionsDTO) throws {
        let selection = try UFitReturnSelection(draft: draft, options: options)
        requestId = requestID; reason = UFitServerTextInput.trimmed(draft.reason); quoteFingerprint = quote.fingerprint; items = selection.items
        try validate()
    }
    func validate() throws {
        guard UUID(uuidString: requestId) != nil, UFitServerTextInput.valid(reason, maximum: UFitReturnInput.reasonMaximum),
              quoteFingerprint.range(of: UFitReturnInput.fingerprintPattern, options: .regularExpression) != nil,
              UFitReturnContract.validItems(items.map(\.orderItemId)), items.allSatisfy({ UFitReturnContract.quantity($0.quantity) }) else { throw UFitReturnContractError.draft }
    }
    var draft: UFitReturnCreationDraft { .init(reason: reason, quantities: Dictionary(uniqueKeysWithValues: items.map { ($0.orderItemId, $0.quantity) })) }
}
struct UFitReturnActionRequest: Encodable {
    let command: UFitReturnCommand
    let draft: UFitReturnActionDraft?
    let items: [UFitReturnRestockDTO]
    init(command: UFitReturnCommand, draft: UFitReturnActionDraft?, detail: UFitReturnDetailDTO) throws {
        guard command.expectedVersion == detail.version, (UFitReturnInput.initialVersion..<UFitReturnInput.maximumVersion).contains(command.expectedVersion),
              detail.actions.contains(command.action), command.action.requiresForm == (draft != nil) else { throw UFitReturnContractError.draft }
        if let draft {
            let pieces = detail.items.map { item in UFitOrderPiece(id: item.id, name: item.name, image: nil, options: String(), quantity: item.quantity, amount: String()) }
            guard UFitReturnInput.errors(draft, action: command.action, pieces: pieces).isEmpty else { throw UFitReturnContractError.draft }
        }
        self.command = command; self.draft = draft
        if command.action == .receive, let draft {
            items = try detail.items.map { item in
                guard let quantity = draft.restockQuantities[item.id] else { throw UFitReturnContractError.draft }
                return .init(orderItemId: item.id, restockQuantity: quantity)
            }
        } else { items = [] }
    }
    private enum CodingKeys: String, CodingKey { case action, expectedVersion, reason, instructions, carrier, trackingNumber, trackingUrl, items }
    func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(command.action, forKey: .action); try values.encode(command.expectedVersion, forKey: .expectedVersion)
        if let draft {
            if command.action.needsReason { try values.encode(UFitServerTextInput.trimmed(draft.reason), forKey: .reason) }
            if command.action.needsInstructions { try values.encode(UFitServerTextInput.trimmed(draft.instructions), forKey: .instructions) }
            if command.action.needsTracking {
                try values.encode(UFitServerTextInput.trimmed(draft.carrier), forKey: .carrier)
                try values.encode(UFitServerTextInput.trimmed(draft.trackingNumber), forKey: .trackingNumber)
                let link = UFitServerTextInput.trimmed(draft.trackingURL)
                if link.isEmpty { try values.encodeNil(forKey: .trackingUrl) } else { try values.encode(link, forKey: .trackingUrl) }
            }
            if command.action == .receive { try values.encode(items, forKey: .items) }
        }
    }
}
extension UFitAPIClient {
    func fetchReturns(scope: UFitReturnScope, status: UFitReturnStatus?, cursor: String?) async throws -> UFitReturnsPageDTO {
        var query = [URLQueryItem(name: UFitReturnsHTTP.limit, value: String(UFitReturnsHTTP.pageLimit))]
        if let status { query.append(.init(name: UFitReturnsHTTP.status, value: status.rawValue)) }
        if let cursor {
            guard UUID(uuidString: cursor) != nil else { throw UFitReturnContractError.page }
            query.append(.init(name: UFitReturnsHTTP.cursor, value: cursor))
        }
        do {
            let result: UFitReturnsPageDTO = try await send(UFitReturnsHTTP.get, path: scope.path, query: query, requiresAuth: true)
            try result.validate(scope: scope, cursor: cursor, status: status); return result
        } catch is DecodingError { throw UFitReturnContractError.page }
    }
    func fetchReturn(scope: UFitReturnScope, id: String) async throws -> UFitReturnDetailDTO {
        guard UUID(uuidString: id) != nil else { throw UFitReturnContractError.draft }
        do {
            let result: UFitReturnDetailDTO = try await send(UFitReturnsHTTP.get, path: scope.path + UFitReturnsHTTP.separator + id, requiresAuth: true)
            try result.validate(scope: scope, expectedID: id); return result
        } catch is DecodingError { throw UFitReturnContractError.document }
    }
    func fetchReturnOptions(orderID: String) async throws -> UFitReturnOptionsDTO {
        do {
            let result: UFitReturnOptionsDTO = try await send(UFitReturnsHTTP.get, path: UFitReturnScope.customer(orderID: orderID).path + UFitReturnsHTTP.options, requiresAuth: true)
            try result.validate(orderID: orderID); return result
        } catch is DecodingError { throw UFitReturnContractError.document }
    }
    func previewReturn(orderID: String, draft: UFitReturnCreationDraft, options: UFitReturnOptionsDTO) async throws -> UFitReturnQuoteDTO {
        guard options.orderId == orderID, options.canRequest else { throw UFitReturnContractError.draft }
        let body = try UFitReturnSelection(draft: draft, options: options)
        do {
            let result: UFitReturnQuoteDTO = try await send(UFitReturnsHTTP.post, path: UFitReturnScope.customer(orderID: orderID).path + UFitReturnsHTTP.preview, body: body, requiresAuth: true)
            try result.validate(orderID: orderID, options: options); return result
        } catch is DecodingError { throw UFitReturnContractError.document }
    }
    func createReturn(orderID: String, request: UFitReturnCreationRequest) async throws -> UFitReturnDetailDTO {
        try request.validate()
        let scope = UFitReturnScope.customer(orderID: orderID)
        do {
            let result: UFitReturnDetailDTO = try await send(UFitReturnsHTTP.post, path: scope.path, body: request, requiresAuth: true)
            try result.validate(scope: scope)
            guard result.reason == request.reason,
                  Dictionary(uniqueKeysWithValues: result.items.map { ($0.id, $0.quantity) }) == Dictionary(uniqueKeysWithValues: request.items.map { ($0.orderItemId, $0.quantity) }) else { throw UFitReturnContractError.document }
            return result
        } catch is DecodingError { throw UFitReturnContractError.document }
    }
    func performReturn(scope: UFitReturnScope, detail: UFitReturnDetailDTO, command: UFitReturnCommand, draft: UFitReturnActionDraft? = nil) async throws -> UFitReturnDetailDTO {
        try detail.validate(scope: scope, expectedID: detail.id)
        let body = try UFitReturnActionRequest(command: command, draft: draft, detail: detail)
        do {
            let result: UFitReturnDetailDTO = try await send(UFitReturnsHTTP.post, path: scope.path + UFitReturnsHTTP.separator + detail.id + UFitReturnsHTTP.actions, body: body, requiresAuth: true)
            try result.validate(scope: scope, expectedID: detail.id)
            guard result.version == detail.version + UFitReturnInput.versionStep, result.orderId == detail.orderId, result.brandId == detail.brandId else { throw UFitReturnContractError.document }
            return result
        } catch is DecodingError { throw UFitReturnContractError.document }
    }
}
