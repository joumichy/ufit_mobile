import Foundation

/// Keeps the exact creation request across process interruption, until its outcome is known.
struct UFitCatalogCreationJournal {
    let userID: String
    let brandID: String
    private enum Storage {
        static let directory = "CatalogCreations"
        static let separator = "-"
        static let fileExtension = "json"
        static let privatePermissions = 0o600
    }
    private var file: URL {
        get throws {
            guard UUID(uuidString: userID) != nil, UUID(uuidString: brandID) != nil,
                  let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { throw UFitCatalogContractError.draft }
            return support.appendingPathComponent(Storage.directory, isDirectory: true)
                .appendingPathComponent(userID + Storage.separator + brandID).appendingPathExtension(Storage.fileExtension)
        }
    }
    func read() throws -> UFitCatalogWriteRequest? {
        let url = try file
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let request = try JSONDecoder().decode(UFitCatalogWriteRequest.self, from: Data(contentsOf: url))
        guard request.brandId == brandID, let requestID = request.requestId, UUID(uuidString: requestID) != nil, request.expectedVersion == nil else { throw UFitCatalogContractError.draft }
        return request
    }
    func record(_ request: UFitCatalogWriteRequest) throws {
        guard request.brandId == brandID, request.requestId != nil, request.expectedVersion == nil else { throw UFitCatalogContractError.draft }
        let url = try file
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(request).write(to: url, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: Storage.privatePermissions], ofItemAtPath: url.path)
    }
    func resolve() throws {
        let url = try file
        if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
    }
}
