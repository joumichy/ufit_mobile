import Foundation

struct UFitOutfitPendingCreation: Codable {
    let request: UFitOutfitWriteRequest
    let draft: UFitOutfitDraft
    let metadata: UFitOutfitMetadata
    func validate(scope: UFitOutfitScope) throws {
        guard request.creationScope == scope, request.expectedVersion == nil,
              let requestID = request.requestId.flatMap(UUID.init(uuidString:)) else { throw UFitOutfitContractError.draft }
        try metadata.validate()
        let expected = try UFitOutfitWriteRequest(draft: draft, tags: metadata.tags, scope: scope, requestID: requestID, editing: nil)
        guard expected == request else { throw UFitOutfitContractError.draft }
    }
}
struct UFitOutfitCreationJournal {
    let userID: String
    let scope: UFitOutfitScope
    private enum Storage {
        static let directory = "OutfitCreations"; static let separator = "-"; static let fileExtension = "json"
        static let permissions = 0o600
    }
    private var file: URL {
        get throws {
            guard UUID(uuidString: userID) != nil, UUID(uuidString: scope.profileID) != nil,
                  let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { throw UFitOutfitContractError.draft }
            let identity = [userID, scope.kind.rawValue, scope.profileID].joined(separator: Storage.separator)
            return support.appendingPathComponent(Storage.directory, isDirectory: true).appendingPathComponent(identity).appendingPathExtension(Storage.fileExtension)
        }
    }
    func read() throws -> UFitOutfitPendingCreation? {
        let url = try file
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let pending = try JSONDecoder().decode(UFitOutfitPendingCreation.self, from: Data(contentsOf: url))
        try pending.validate(scope: scope); return pending
    }
    func record(_ pending: UFitOutfitPendingCreation) throws {
        try pending.validate(scope: scope)
        let url = try file
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(pending).write(to: url, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: Storage.permissions], ofItemAtPath: url.path)
    }
    func resolve() throws {
        let url = try file
        if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
    }
}
