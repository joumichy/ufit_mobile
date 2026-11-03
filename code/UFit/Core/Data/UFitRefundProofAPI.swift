import Foundation
import CryptoKit

enum UFitRefundProofContract {
    static let root = "/proofs", commands = "/commands/", fileSuffix = "/file", separator = "/"
    static let pdf = "application/pdf", jpeg = "image/jpeg", currencyPattern = "^[A-Z]{3}$", hashPattern = "^[a-f0-9]{64}$"
    static let maximumBytes = 8 * 1024 * 1024, minimumBytes = 5, referenceMaximum = 160
    static let dateFormat = "yyyy-MM-dd", dateLength = 10, locale = Locale(identifier: "en_US_POSIX"), timeZone = TimeZone(secondsFromGMT: .zero)!
    static let pending = "pending", submitted = "submitted", missingReceipt = "refund_proof_receipt_missing", file = "file", filename = "justificatif"
    static let request = "requestId", version = "expectedVersion", reference = "transferReference", date = "transferredOn"
    static let command = "command", historyLimit = "limit", historyCursor = "cursor", pageSize = 20
    static func dateValue(_ text: String) -> Date? {
        let formatter = DateFormatter(); formatter.locale = locale; formatter.calendar = Calendar(identifier: .iso8601); formatter.timeZone = timeZone; formatter.dateFormat = dateFormat; formatter.isLenient = false
        guard text.count == dateLength, let date = formatter.date(from: text), formatter.string(from: date) == text else {return nil}
        return date
    }
    static func hash(_ bytes: Data) -> String {SHA256.hash(data: bytes).map {String(format: HashFormat.byte, $0)}.joined()}
    private enum HashFormat {static let byte = "%02x"}
}
struct UFitRefundProofDTO: Decodable {
    struct File: Decodable {
        let contentType: String
        let byteSize: Int
        let sha256: String
        private enum CodingKeys: String, CodingKey, CaseIterable {case contentType, byteSize, sha256}
        init(from decoder: Decoder) throws {
            try UFitStrictDecoding.keys(decoder, CodingKeys.self, failure: UFitRefundOrganizationFailure.contract)
            let values = try decoder.container(keyedBy: CodingKeys.self)
            contentType = try values.decode(String.self, forKey: .contentType); byteSize = try values.decode(Int.self, forKey: .byteSize); sha256 = try values.decode(String.self, forKey: .sha256)
            guard [UFitRefundProofContract.pdf, UFitRefundProofContract.jpeg].contains(contentType),
                  (UFitRefundProofContract.minimumBytes...UFitRefundProofContract.maximumBytes).contains(byteSize), sha256.range(of: UFitRefundProofContract.hashPattern, options: .regularExpression) != nil else {throw UFitRefundOrganizationFailure.contract}
        }
    }
    let id: String
    let sequence: Int
    let status: UFitRefundProofStatus
    @UFitRequiredNullable var review: UFitRefundProofReviewDTO?
    let organizationVersion: Int
    let amount: Int
    let currency: String
    let transferReference: String
    let transferredOn: String
    let submittedAt: UFitTimestamp
    let transferredOnDate: Date
    let file: File
    private enum CodingKeys: String, CodingKey, CaseIterable {case id, sequence, status, review, organizationVersion, amount, currency, transferReference, transferredOn, submittedAt, file}
    init(from decoder: Decoder) throws {
        try UFitStrictDecoding.keys(decoder, CodingKeys.self, failure: UFitRefundOrganizationFailure.contract)
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(String.self, forKey: .id); organizationVersion = try values.decode(Int.self, forKey: .organizationVersion)
        sequence = try values.decode(Int.self, forKey: .sequence); status = try values.decode(UFitRefundProofStatus.self, forKey: .status)
        _review = try values.decode(UFitRequiredNullable<UFitRefundProofReviewDTO>.self, forKey: .review)
        amount = try values.decode(Int.self, forKey: .amount); currency = try values.decode(String.self, forKey: .currency)
        transferReference = try values.decode(String.self, forKey: .transferReference); transferredOn = try values.decode(String.self, forKey: .transferredOn)
        submittedAt = try values.decode(UFitTimestamp.self, forKey: .submittedAt); file = try values.decode(File.self, forKey: .file)
        guard let date = UFitRefundProofContract.dateValue(transferredOn) else {throw UFitRefundOrganizationFailure.contract}
        transferredOnDate = date
        guard UUID(uuidString: id) != nil, (UFitRefundOrganizationRules.firstVersion...UFitRefundOrganizationRules.maximumVersion).contains(organizationVersion), amount > .zero,
              (UFitRefundOrganizationRules.firstVersion...UFitRefundOrganizationRules.maximumVersion).contains(sequence),
              (status == .submitted && review == nil) || (status == .rejected && review?.decision == .reject) || (status == .verified && review?.decision == .confirm),
              currency.range(of: UFitRefundProofContract.currencyPattern, options: .regularExpression) != nil,
              UFitServerTextInput.valid(transferReference, maximum: UFitRefundProofContract.referenceMaximum), UFitRefundProofContract.dateValue(transferredOn) != nil else {throw UFitRefundOrganizationFailure.contract}
    }
}

struct UFitRefundProofReceiptDTO: Decodable {
    enum State: String, Decodable {case pending, submitted}
    let requestId: String
    let state: State
    @UFitRequiredNullable var proof: UFitRefundProofDTO?
    private enum CodingKeys: String, CodingKey, CaseIterable {case requestId, state, proof}
    init(from decoder: Decoder) throws {
        try UFitStrictDecoding.keys(decoder, CodingKeys.self, failure: UFitRefundOrganizationFailure.contract)
        let values = try decoder.container(keyedBy: CodingKeys.self)
        requestId = try values.decode(String.self, forKey: .requestId); state = try values.decode(State.self, forKey: .state)
        _proof = try values.decode(UFitRequiredNullable<UFitRefundProofDTO>.self, forKey: .proof)
        guard (state == .pending) == (proof == nil) else {throw UFitRefundOrganizationFailure.contract}
    }
    func validate(_ request: UFitRefundProofRequest) throws {
        guard requestId == request.requestId else {throw UFitRefundOrganizationFailure.contract}
        if let proof {guard proof.organizationVersion == request.expectedVersion, proof.transferReference == request.transferReference, proof.transferredOn == request.transferredOn,
                            proof.file.sha256 == request.file.sha256, proof.file.byteSize == request.file.bytes.count, proof.file.contentType == request.file.contentType else {throw UFitRefundOrganizationFailure.contract}}
    }
}
extension UFitAPIClient {
    func uploadRefundProof(reference: UFitRefundRecoveryReference, request: UFitRefundProofRequest) async throws -> UFitRefundProofReceiptDTO {
        try request.validate()
        let command = try JSONEncoder().encode(UFitRefundProofRequest.Command(request: request))
        let fields = [(UFitRefundProofContract.command, String(decoding: command, as: UTF8.self))]
        let name = UFitRefundProofContract.filename + (request.file.contentType == UFitRefundProofContract.pdf ? FileExtension.pdf : FileExtension.jpeg)
        let body = UFitMultipartEncoding.file(fields: fields, bytes: request.file.bytes, name: name, mime: request.file.contentType)
        let result: UFitRefundProofReceiptDTO = try await send(UFitRefundOrganizationHTTP.post, path: proofPath(reference), multipart: body, requiresAuth: true)
        try result.validate(request); return result
    }
    func refundProofReceipt(reference: UFitRefundRecoveryReference, request: UFitRefundProofRequest) async throws -> UFitRefundProofReceiptDTO {
        let result: UFitRefundProofReceiptDTO = try await send(UFitRefundOrganizationHTTP.get, path: proofPath(reference) + UFitRefundProofContract.commands + request.requestId, requiresAuth: true)
        try result.validate(request); return result
    }
    func downloadRefundProof(scope: UFitRefundOrganizationScope, reference: UFitRefundRecoveryReference, proof: UFitRefundProofDTO) async throws -> Data {
        let root = scope == .administrator ? UFitRefundRecoveryHTTP.path : UFitRefundOrganizationHTTP.privateRoot
        let path = root + UFitRefundProofContract.separator + reference.kind.rawValue + UFitRefundProofContract.separator + reference.id + UFitRefundProofContract.root + UFitRefundProofContract.separator + proof.id + UFitRefundProofContract.fileSuffix
        let query = scope == .administrator ? [] : [URLQueryItem(name: UFitRefundOrganizationHTTP.scope, value: scope.rawValue)]
        let result = try await downloadPrivateDocument(path: path, query: query, contentType: proof.file.contentType)
        guard result.contentType == proof.file.contentType, result.data.count == proof.file.byteSize, UFitRefundProofContract.hash(result.data) == proof.file.sha256 else {throw UFitRefundOrganizationFailure.contract}
        return result.data
    }
    private func proofPath(_ reference: UFitRefundRecoveryReference) -> String {UFitRefundOrganizationHTTP.privateRoot + UFitRefundProofContract.separator + reference.kind.rawValue + UFitRefundProofContract.separator + reference.id + UFitRefundProofContract.root}
    private enum FileExtension {static let pdf = ".pdf", jpeg = ".jpg"}
}
