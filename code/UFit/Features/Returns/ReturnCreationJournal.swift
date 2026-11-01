import Foundation

/// A replay uses the exact original request until the server confirms its outcome.
struct UFitReturnCreationJournal {
    let userID: String
    let orderID: String
    private struct Record: Codable { let userID: String; let orderID: String; let request: UFitReturnCreationRequest }
    private enum Storage {
        static let directory = "ReturnCreations"; static let separator = "-"; static let fileExtension = "json"; static let privatePermissions = 0o600
    }
    private var file: URL {
        get throws {
            guard UUID(uuidString: userID) != nil, UUID(uuidString: orderID) != nil,
                  let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { throw UFitReturnContractError.draft }
            return support.appendingPathComponent(Storage.directory, isDirectory: true)
                .appendingPathComponent(userID + Storage.separator + orderID).appendingPathExtension(Storage.fileExtension)
        }
    }
    func read() throws -> UFitReturnCreationRequest? {
        let url = try file
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let record = try JSONDecoder().decode(Record.self, from: Data(contentsOf: url))
        guard record.userID == userID, record.orderID == orderID else { throw UFitReturnContractError.draft }
        try record.request.validate(); return record.request
    }
    func record(_ request: UFitReturnCreationRequest) throws {
        try request.validate()
        let url = try file
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(Record(userID: userID, orderID: orderID, request: request)).write(to: url, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: Storage.privatePermissions], ofItemAtPath: url.path)
    }
    func resolve() throws {
        let url = try file
        if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
    }
}
