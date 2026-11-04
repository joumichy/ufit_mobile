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
        static let request = "request"; static let draft = "draft"; static let photos = "photos"; static let pins = "pins"
        static let metadata = "metadata"; static let itemTypes = "itemTypes"
        static let priorTypes: Set<String> = ["top", "bottom", "shoes", "bag", "accessory", "outerwear"]
        static let priorIconTypes = priorTypes.union(["eyewear", "headwear"])
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
        let data = try Data(contentsOf: url)
        let pinsMigrated = try migratePins(data)
        let migrated = try migrateItemTypes(pinsMigrated ?? data) ?? pinsMigrated
        let pending = try JSONDecoder().decode(UFitOutfitPendingCreation.self, from: migrated ?? data)
        try pending.validate(scope: scope)
        if migrated != nil { try record(pending) }
        return pending
    }
    private func migratePins(_ data: Data) throws -> Data? {
        guard var root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              var request = root[Storage.request] as? [String: Any], request[Storage.pins] == nil else { return nil }
        guard var draft = root[Storage.draft] as? [String: Any], var photos = draft[Storage.photos] as? [[String: Any]],
              photos.allSatisfy({ $0[Storage.pins] == nil }), var metadata = root[Storage.metadata] as? [String: Any],
              let types = metadata[Storage.itemTypes] as? [String], Set(types) == Storage.priorTypes else { throw UFitOutfitContractError.draft }
        request[Storage.pins] = [] as [String]
        for index in photos.indices { photos[index][Storage.pins] = [] as [String] }
        draft[Storage.photos] = photos; metadata[Storage.itemTypes] = UFitOutfitItemType.allCases.map(\.rawValue)
        root[Storage.request] = request; root[Storage.draft] = draft; root[Storage.metadata] = metadata
        return try JSONSerialization.data(withJSONObject: root)
    }
    // Upgrade only the known eight-type metadata snapshot; the saved request is unchanged.
    private func migrateItemTypes(_ data: Data) throws -> Data? {
        guard var root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              var metadata = root[Storage.metadata] as? [String: Any],
              let types = metadata[Storage.itemTypes] as? [String],
              types.count == Storage.priorIconTypes.count, Set(types) == Storage.priorIconTypes else { return nil }
        metadata[Storage.itemTypes] = UFitOutfitItemType.allCases.map(\.rawValue)
        root[Storage.metadata] = metadata
        return try JSONSerialization.data(withJSONObject: root)
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
