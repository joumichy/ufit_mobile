import Foundation

enum UFitRefundOrganizationHTTP {
    static let get = "GET", post = "POST", privateRoot = "refund-recoveries", organization = "/organization", commands = "/commands/", separator = "/", scope = "scope"
    static let missingReceipt = "refund_organization_receipt_missing", changed = "refund_organization_changed"
    static let conflict = 409, badRequest = 400, notFound = 404, forbidden = 403, unauthorized = 401
    static func path(scope: UFitRefundOrganizationScope, reference: UFitRefundRecoveryReference) -> String {
        let root = scope == .administrator ? UFitRefundRecoveryHTTP.path : privateRoot
        return root + separator + reference.kind.rawValue + separator + reference.id + organization
    }
}
enum UFitRefundOrganizationFailure: LocalizedError {
    case contract, localRecord
    var errorDescription: String? {
        switch self {
        case .contract: String(localized: "Le dossier reçu est incohérent. Actualisez le remboursement.")
        case .localRecord: String(localized: "La demande locale ne peut pas être relue. Son enregistrement doit être vérifié avant une nouvelle saisie.")
        }
    }
}
struct UFitRefundOrganizationDTO: Decodable {
    let version: Int
    let status: UFitRefundOrganizationStatus
    let methodLabel: String
    let instructions: String
    @UFitRequiredNullable var customerDetails: String?
    let updatedAt: UFitTimestamp
    private enum CodingKeys: String, CodingKey, CaseIterable {case version, status, methodLabel, instructions, customerDetails, updatedAt}
    init(from decoder: Decoder) throws {
        try UFitStrictDecoding.keys(decoder, CodingKeys.self, failure: UFitRefundOrganizationFailure.contract)
        let v = try decoder.container(keyedBy: CodingKeys.self)
        version = try v.decode(Int.self, forKey: .version); status = try v.decode(UFitRefundOrganizationStatus.self, forKey: .status)
        methodLabel = try v.decode(String.self, forKey: .methodLabel); instructions = try v.decode(String.self, forKey: .instructions)
        _customerDetails = try v.decode(UFitRequiredNullable<String>.self, forKey: .customerDetails); updatedAt = try v.decode(UFitTimestamp.self, forKey: .updatedAt)
        guard (UFitRefundOrganizationRules.firstVersion...UFitRefundOrganizationRules.maximumVersion).contains(version),
              UFitServerTextInput.valid(methodLabel, maximum: UFitRefundOrganizationRules.methodMaximum), UFitServerTextInput.valid(instructions, maximum: UFitRefundOrganizationRules.instructionsMaximum),
              (status == .awaitingCustomer) == (customerDetails == nil), customerDetails == nil || UFitServerTextInput.valid(customerDetails!, maximum: UFitRefundOrganizationRules.detailsMaximum) else {throw UFitRefundOrganizationFailure.contract}
    }
}
struct UFitRefundOrganizationDocumentDTO: Decodable {
    let summary: UFitRefundRecoverySummaryDTO
    @UFitRequiredNullable var organization: UFitRefundOrganizationDTO?
    @UFitRequiredNullable var proof: UFitRefundProofDTO?
    let actions: [UFitRefundOrganizationAction]
    private enum CodingKeys: String, CodingKey, CaseIterable {case summary, organization, proof, actions}
    init(from decoder: Decoder) throws {
        try UFitStrictDecoding.keys(decoder, CodingKeys.self, failure: UFitRefundOrganizationFailure.contract)
        let v = try decoder.container(keyedBy: CodingKeys.self)
        summary = try v.decode(UFitRefundRecoverySummaryDTO.self, forKey: .summary)
        _organization = try v.decode(UFitRequiredNullable<UFitRefundOrganizationDTO>.self, forKey: .organization)
        _proof = try v.decode(UFitRequiredNullable<UFitRefundProofDTO>.self, forKey: .proof)
        actions = try v.decode([UFitRefundOrganizationAction].self, forKey: .actions)
    }
    func validate(scope: UFitRefundOrganizationScope, reference: UFitRefundRecoveryReference) throws {
        let expected: [UFitRefundOrganizationAction]
        if proof != nil || organization?.version == UFitRefundOrganizationRules.maximumVersion {expected = []}
        else {switch scope {case .administrator: expected = [.arrange]; case .customer: expected = organization == nil ? [] : [.provideDetails]; case .brand: expected = []}}
        if let proof {guard proof.organizationVersion == organization?.version, proof.amount == summary.amount, proof.currency == summary.currency else {throw UFitRefundOrganizationFailure.contract}}
        guard summary.reference == reference, actions == expected else {throw UFitRefundOrganizationFailure.contract}
    }
}
struct UFitRefundOrganizationRequest: Codable, Equatable {
    let requestId: String
    let expectedVersion: Int
    let action: UFitRefundOrganizationAction
    let methodLabel: String?
    let instructions: String?
    let details: String?
    init(action: UFitRefundOrganizationAction, version: Int, draft: UFitRefundOrganizationDraft) throws {
        requestId = UUID().uuidString.lowercased(); expectedVersion = version; self.action = action
        methodLabel = action == .arrange ? UFitServerTextInput.trimmed(draft.methodLabel) : nil
        instructions = action == .arrange ? UFitServerTextInput.trimmed(draft.instructions) : nil
        details = action == .provideDetails ? UFitServerTextInput.trimmed(draft.details) : nil
        try validate()
    }
    var draft: UFitRefundOrganizationDraft {.init(methodLabel: methodLabel ?? String(), instructions: instructions ?? String(), details: details ?? String())}
    func validate() throws {
        guard UUID(uuidString: requestId) != nil, (.zero..<UFitRefundOrganizationRules.maximumVersion).contains(expectedVersion), UFitRefundOrganizationRules.errors(draft, action: action).isEmpty else {throw UFitRefundOrganizationFailure.localRecord}
        switch action {
        case .arrange: guard methodLabel != nil, instructions != nil, details == nil else {throw UFitRefundOrganizationFailure.localRecord}
        case .provideDetails: guard methodLabel == nil, instructions == nil, details != nil, expectedVersion >= UFitRefundOrganizationRules.firstVersion else {throw UFitRefundOrganizationFailure.localRecord}
        }
    }
}
struct UFitRefundOrganizationResultDTO: Decodable {
    struct Receipt: Decodable {
        let requestId: String
        let version: Int
        private enum CodingKeys: String, CodingKey, CaseIterable {case requestId, version}
        init(from decoder: Decoder) throws {
            try UFitStrictDecoding.keys(decoder, CodingKeys.self, failure: UFitRefundOrganizationFailure.contract)
            let values = try decoder.container(keyedBy: CodingKeys.self)
            requestId = try values.decode(String.self, forKey: .requestId); version = try values.decode(Int.self, forKey: .version)
        }
    }
    let document: UFitRefundOrganizationDocumentDTO
    let receipt: Receipt
    private enum CodingKeys: String, CodingKey, CaseIterable {case document, receipt}
    init(from decoder: Decoder) throws {
        try UFitStrictDecoding.keys(decoder, CodingKeys.self, failure: UFitRefundOrganizationFailure.contract)
        let values = try decoder.container(keyedBy: CodingKeys.self)
        document = try values.decode(UFitRefundOrganizationDocumentDTO.self, forKey: .document)
        receipt = try values.decode(Receipt.self, forKey: .receipt)
    }
    func validate(scope: UFitRefundOrganizationScope, reference: UFitRefundRecoveryReference, request: UFitRefundOrganizationRequest) throws {
        try document.validate(scope: scope, reference: reference)
        guard receipt.requestId == request.requestId, receipt.version == request.expectedVersion + UFitRefundOrganizationRules.versionStep,
              let version = document.organization?.version, version >= receipt.version else {throw UFitRefundOrganizationFailure.contract}
    }
}
extension UFitAPIClient {
    func fetchRefundOrganization(scope: UFitRefundOrganizationScope, reference: UFitRefundRecoveryReference) async throws -> UFitRefundOrganizationDocumentDTO {
        let query = scope == .administrator ? [] : [URLQueryItem(name: UFitRefundOrganizationHTTP.scope, value: scope.rawValue)]
        let result: UFitRefundOrganizationDocumentDTO = try await send(UFitRefundOrganizationHTTP.get, path: UFitRefundOrganizationHTTP.path(scope: scope, reference: reference), query: query, requiresAuth: true)
        try result.validate(scope: scope, reference: reference); return result
    }
    func applyRefundOrganization(scope: UFitRefundOrganizationScope, reference: UFitRefundRecoveryReference, request: UFitRefundOrganizationRequest) async throws -> UFitRefundOrganizationResultDTO {
        try request.validate()
        let result: UFitRefundOrganizationResultDTO = try await send(UFitRefundOrganizationHTTP.post, path: UFitRefundOrganizationHTTP.path(scope: scope, reference: reference), body: request, requiresAuth: true)
        try result.validate(scope: scope, reference: reference, request: request); return result
    }
    func refundOrganizationReceipt(scope: UFitRefundOrganizationScope, reference: UFitRefundRecoveryReference, request: UFitRefundOrganizationRequest) async throws -> UFitRefundOrganizationResultDTO {
        try request.validate()
        let result: UFitRefundOrganizationResultDTO = try await send(UFitRefundOrganizationHTTP.get, path: UFitRefundOrganizationHTTP.path(scope: scope, reference: reference) + UFitRefundOrganizationHTTP.commands + request.requestId, requiresAuth: true)
        try result.validate(scope: scope, reference: reference, request: request); return result
    }
}
