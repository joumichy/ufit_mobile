import Foundation
import CryptoKit

/// Only unresolved commands are kept locally. Confirmed addresses live in the private server book.
struct UFitShippingAddressJournal {
    let userID: String
    let endpoint: URL
    private struct Record: Codable { let version: Int; let endpoint: String; let command: UFitShippingAddressCommand }
    private enum Storage {
        static let version = 1, directory = "ShippingAddressRequests", fileExtension = "json", byteFormat = "%02x"
        static let filePermissions = 0o600, directoryPermissions = 0o700
    }
    private var file: URL {
        get throws {
            guard UFitShippingAddressesHTTP.uuid(userID), endpoint.user == nil, endpoint.password == nil,
                  endpoint.query == nil, endpoint.fragment == nil,
                  let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
                throw UFitShippingAddressFailure.storage
            }
            let key = SHA256.hash(data: Data(endpoint.absoluteString.utf8)).map { String(format: Storage.byteFormat, $0) }.joined()
            return support.appendingPathComponent(Storage.directory, isDirectory: true)
                .appendingPathComponent(userID, isDirectory: true).appendingPathComponent(key).appendingPathExtension(Storage.fileExtension)
        }
    }
    func read() throws -> UFitShippingAddressCommand? {
        let url = try file
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let record = try JSONDecoder().decode(Record.self, from: Data(contentsOf: url))
        guard record.version == Storage.version, record.endpoint == endpoint.absoluteString else { throw UFitShippingAddressFailure.storage }
        try record.command.validate(userID: userID)
        return record.command
    }
    func write(_ command: UFitShippingAddressCommand) throws {
        try command.validate(userID: userID)
        let url = try file
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true,
            attributes: [.posixPermissions: Storage.directoryPermissions])
        let record = Record(version: Storage.version, endpoint: endpoint.absoluteString, command: command)
        try JSONEncoder().encode(record).write(to: url, options: [.atomic, .completeFileProtection])
        try FileManager.default.setAttributes([.posixPermissions: Storage.filePermissions], ofItemAtPath: url.path)
    }
    func clear() throws {
        let url = try file
        if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
    }
}
