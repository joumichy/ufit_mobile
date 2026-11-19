import Foundation

enum UFitShippingAddressesHTTP {
    static let root = "me/shipping-addresses/", countries = "countries", addresses = "/addresses/", changes = "/changes/"
    static let get = "GET", put = "PUT", pageSize = 20, maximumVersion = 2_147_483_647, versionStep = 1
    static let limitQuery = "limit", cursorQuery = "cursor"
    static let changed = "shipping_addresses_changed", reused = "shipping_address_request_changed"
    static let invalid = "shipping_addresses_invalid", unavailable = "shipping_addresses_unavailable", missing = "shipping_address_not_found"
    static func uuid(_ value: String) -> Bool { UUID(uuidString: value)?.uuidString.lowercased() == value }
}
struct UFitShippingAddressItem: Decodable, Identifiable, Equatable {
    let id: String
    let shippingAddress: UFitShippingAddress
    let createdAt: UFitTimestamp
    let updatedAt: UFitTimestamp
    func validate() throws {
        guard UFitShippingAddressesHTTP.uuid(id), updatedAt.value >= createdAt.value else { throw UFitShippingAddressFailure.document }
        try shippingAddress.validate()
    }
}
struct UFitShippingAddressPage: Decodable {
    let userId: String
    let version: Int
    @UFitRequiredNullable var defaultAddressId: String?
    let items: [UFitShippingAddressItem]
    @UFitRequiredNullable var nextCursor: String?
    func validate(userID: String, cursor: String?) throws {
        guard userId == userID, UFitShippingAddressesHTTP.uuid(userId),
              (.zero...UFitShippingAddressesHTTP.maximumVersion).contains(version),
              items.count <= UFitShippingAddressesHTTP.pageSize, Set(items.map(\.id)).count == items.count,
              defaultAddressId.map(UFitShippingAddressesHTTP.uuid) ?? true,
              nextCursor.map({ !$0.isEmpty && $0 != cursor && !items.isEmpty }) ?? true,
              version != .zero || items.isEmpty && defaultAddressId == nil && nextCursor == nil else { throw UFitShippingAddressFailure.document }
        try items.forEach { try $0.validate() }
    }
}
struct UFitShippingAddressInput: Codable, Equatable {
    enum Action: String, Codable { case save, delete, setDefault = "set_default" }
    let expectedVersion: Int
    let action: Action
    let addressId: String?
    var shippingAddress: UFitShippingAddress? = nil
    var makeDefault: Bool? = nil
    enum CodingKeys: String, CodingKey { case expectedVersion, action, addressId, shippingAddress, makeDefault }
    func encode(to encoder: Encoder) throws {
        var value = encoder.container(keyedBy: CodingKeys.self)
        try value.encode(expectedVersion, forKey: .expectedVersion)
        try value.encode(action, forKey: .action)
        try value.encode(addressId, forKey: .addressId)
        if action == .save {
            try value.encode(shippingAddress, forKey: .shippingAddress)
            try value.encode(makeDefault, forKey: .makeDefault)
        }
    }
    func validate() throws {
        guard (.zero..<UFitShippingAddressesHTTP.maximumVersion).contains(expectedVersion),
              addressId.map(UFitShippingAddressesHTTP.uuid) ?? (action == .setDefault) else { throw UFitShippingAddressFailure.document }
        if action == .save {
            guard let shippingAddress, makeDefault != nil else { throw UFitShippingAddressFailure.document }
            try shippingAddress.validate()
        } else if shippingAddress != nil || makeDefault != nil { throw UFitShippingAddressFailure.document }
    }
}
struct UFitShippingAddressCommand: Codable, Equatable {
    let userID: String
    let requestID: String
    let input: UFitShippingAddressInput
    func validate(userID: String) throws {
        guard self.userID == userID, UFitShippingAddressesHTTP.uuid(userID), UFitShippingAddressesHTTP.uuid(requestID) else {
            throw UFitShippingAddressFailure.document
        }
        try input.validate()
    }
}
struct UFitShippingAddressReceipt: Decodable {
    let requestId: String
    let action: UFitShippingAddressInput.Action
    let version: Int
    @UFitRequiredNullable var addressId: String?
    func validate(_ command: UFitShippingAddressCommand) throws {
        guard requestId == command.requestID, action == command.input.action, addressId == command.input.addressId,
              version == command.input.expectedVersion + UFitShippingAddressesHTTP.versionStep else { throw UFitShippingAddressFailure.document }
    }
}
private struct UFitShippingAddressChange: Decodable { @UFitRequiredNullable var receipt: UFitShippingAddressReceipt? }
private struct UFitShippingCountries: Decodable { let countries: [String] }

extension UFitAPIClient {
    func shippingCountries(reload: Bool = false) async throws -> [UFitCountry] {
        let value: UFitShippingCountries = try await fetchReference(path: UFitShippingAddressesHTTP.root + UFitShippingAddressesHTTP.countries,
            reload: reload) { (value: UFitShippingCountries) in
            guard !value.countries.isEmpty, Set(value.countries).count == value.countries.count,
                  value.countries.allSatisfy({ $0.range(of: UFitCountry.codePattern, options: .regularExpression) != nil }) else {
                throw UFitShippingAddressFailure.document
            }
        }
        return value.countries.map { .init(id: $0, name: UFitCountry.displayLocale.localizedString(forRegionCode: $0) ?? $0) }
            .sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
    }
    func shippingAddresses(userID: String, cursor: String? = nil) async throws -> UFitShippingAddressPage {
        var query = [URLQueryItem(name: UFitShippingAddressesHTTP.limitQuery, value: String(UFitShippingAddressesHTTP.pageSize))]
        if let cursor { query.append(.init(name: UFitShippingAddressesHTTP.cursorQuery, value: cursor)) }
        let value: UFitShippingAddressPage = try await send(UFitShippingAddressesHTTP.get,
            path: UFitShippingAddressesHTTP.root + userID, query: query, requiresAuth: true, cachePolicy: .reloadIgnoringLocalCacheData)
        try value.validate(userID: userID, cursor: cursor)
        return value
    }
    func shippingAddress(userID: String, id: String) async throws -> UFitShippingAddressItem {
        let item: UFitShippingAddressItem = try await send(UFitShippingAddressesHTTP.get,
            path: UFitShippingAddressesHTTP.root + userID + UFitShippingAddressesHTTP.addresses + id,
            requiresAuth: true, cachePolicy: .reloadIgnoringLocalCacheData)
        try item.validate()
        guard item.id == id else { throw UFitShippingAddressFailure.document }
        return item
    }
    func changeShippingAddress(_ command: UFitShippingAddressCommand) async throws -> UFitShippingAddressReceipt {
        try command.validate(userID: command.userID)
        let receipt: UFitShippingAddressReceipt = try await send(UFitShippingAddressesHTTP.put,
            path: UFitShippingAddressesHTTP.root + command.userID + UFitShippingAddressesHTTP.changes + command.requestID,
            body: command.input, requiresAuth: true, publicOutfitsChange: false)
        try receipt.validate(command)
        return receipt
    }
    func shippingAddressReceipt(_ command: UFitShippingAddressCommand) async throws -> UFitShippingAddressReceipt? {
        try command.validate(userID: command.userID)
        let value: UFitShippingAddressChange = try await send(UFitShippingAddressesHTTP.get,
            path: UFitShippingAddressesHTTP.root + command.userID + UFitShippingAddressesHTTP.changes + command.requestID,
            requiresAuth: true, cachePolicy: .reloadIgnoringLocalCacheData)
        try value.receipt?.validate(command)
        return value.receipt
    }
}
