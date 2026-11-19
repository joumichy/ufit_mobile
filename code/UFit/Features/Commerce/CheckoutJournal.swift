import Foundation
import CryptoKit

struct UFitCheckoutRecoveryRecord: Codable, Equatable {
    enum Outcome: Codable, Equatable { case unknown, order(id: String) }
    let version: Int
    let userID: String
    let endpoint: String
    let cartID: String
    let request: UFitCheckoutRequest
    let amount: Int
    let currency: String
    var outcome: Outcome
    var orderID: String? { if case .order(let id) = outcome { id } else { nil } }

    func validate(userID: String, endpoint: String) throws {
        let address = request.shippingAddress
        guard version == UFitCheckoutJournal.version, self.userID == userID, self.endpoint == endpoint,
              UUID(uuidString: userID) != nil, UUID(uuidString: cartID) != nil,
              UUID(uuidString: request.requestId) != nil, request.requestId == request.requestId.lowercased(),
              request.quoteFingerprint.range(of: UFitCheckoutHTTP.fingerprintPattern, options: .regularExpression) != nil,
              amount > .zero, amount <= UFitCustomerPaymentHTTP.maximum,
              currency.range(of: UFitCurrency.codePattern, options: .regularExpression) != nil,
              !address.fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !address.line1.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !address.postalCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !address.city.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              address.country.range(of: UFitCheckoutJournal.countryPattern, options: .regularExpression) != nil else {
            throw UFitCheckoutRecoveryFailure.document
        }
        if let orderID, UUID(uuidString: orderID) == nil { throw UFitCheckoutRecoveryFailure.document }
    }
}

/// Keeps the exact request until the server supplies an order or rejects its quote.
struct UFitCheckoutJournal {
    enum Reconciliation {
        case empty
        case awaitingOrder(UFitCheckoutRecoveryRecord)
        case openOrder(UFitCheckoutRecoveryRecord, UFitOrderDTO)
    }
    let userID: String
    let endpoint: URL
    static let version = 1
    static let countryPattern = "^[A-Z]{2}$"
    private enum Storage {
        static let directory = "CheckoutRequests", fileExtension = "json", digestByte = "%02x"
        static let filePermissions = 0o600, directoryPermissions = 0o700
    }
    private var file: URL {
        get throws {
            guard UUID(uuidString: userID) != nil, endpoint.user == nil, endpoint.password == nil,
                  endpoint.query == nil, endpoint.fragment == nil,
                  let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
                throw UFitCheckoutRecoveryFailure.document
            }
            let key = SHA256.hash(data: Data(endpoint.absoluteString.utf8)).map { String(format: Storage.digestByte, $0) }.joined()
            return support.appendingPathComponent(Storage.directory, isDirectory: true)
                .appendingPathComponent(userID, isDirectory: true).appendingPathComponent(key).appendingPathExtension(Storage.fileExtension)
        }
    }
    func read() throws -> UFitCheckoutRecoveryRecord? {
        do {
            let url = try file
            guard FileManager.default.fileExists(atPath: url.path) else { return nil }
            let record = try JSONDecoder().decode(UFitCheckoutRecoveryRecord.self, from: Data(contentsOf: url))
            try record.validate(userID: userID, endpoint: endpoint.absoluteString)
            return record
        } catch let failure as UFitCheckoutRecoveryFailure { throw failure }
        catch { throw UFitCheckoutRecoveryFailure.localRead }
    }
    func record(_ value: UFitCheckoutRecoveryRecord) throws {
        try value.validate(userID: userID, endpoint: endpoint.absoluteString)
        let url = try file
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true,
            attributes: [.posixPermissions: Storage.directoryPermissions])
        try JSONEncoder().encode(value).write(to: url, options: [.atomic, .completeFileProtection])
        try FileManager.default.setAttributes([.posixPermissions: Storage.filePermissions], ofItemAtPath: url.path)
    }
    static func isResolved(_ order: UFitOrderDTO) -> Bool {
        [.paid, .preparing, .shipped, .delivered, .cancelled, .refunded].contains(order.status)
    }
    func clearForDeletedAccount() throws {
        let url = try file
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        do { try FileManager.default.removeItem(at: url) }
        catch { throw UFitCheckoutRecoveryFailure.localWrite }
    }
    @discardableResult func resolve(_ expected: UFitCheckoutRecoveryRecord) throws -> Bool {
        guard try read() == expected else { return false }
        let url = try file
        do { try FileManager.default.removeItem(at: url) }
        catch { throw UFitCheckoutRecoveryFailure.localWrite }
        return true
    }
    func resolve(confirmedOrder order: UFitOrderDTO) throws {
        guard Self.isResolved(order), let record = try read(), record.orderID == order.id else { return }
        guard order.totalAmount == record.amount, order.currency == record.currency else { throw UFitCheckoutRecoveryFailure.document }
        try resolve(record)
    }
    @MainActor func reconcile(using client: UFitAPIClient, isCurrentAccount: () -> Bool) async throws -> Reconciliation {
        try Task.checkCancellation()
        guard isCurrentAccount() else { throw CancellationError() }
        guard let record = try read() else { return .empty }
        let orderID: String
        if let known = record.orderID { orderID = known }
        else {
            let outcome = try await client.checkoutOutcome(requestID: record.request.requestId, knownOrderID: nil)
            try Task.checkCancellation()
            guard isCurrentAccount() else { throw CancellationError() }
            guard let found = outcome.orderId else {
                guard try read() == record else { throw UFitCheckoutRecoveryFailure.document }
                return .awaitingOrder(record)
            }
            orderID = found
        }
        let order = try await client.fetchOrder(id: orderID)
        try Task.checkCancellation()
        guard isCurrentAccount() else { throw CancellationError() }
        guard order.id == orderID, order.totalAmount == record.amount, order.currency == record.currency else {
            throw UFitCheckoutRecoveryFailure.document
        }
        guard try read() == record else { throw UFitCheckoutRecoveryFailure.document }
        if Self.isResolved(order) {
            guard try resolve(record) else { throw UFitCheckoutRecoveryFailure.document }
            return .empty
        }
        return .openOrder(record, order)
    }
}
