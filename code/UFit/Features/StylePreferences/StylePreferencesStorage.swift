import Foundation

struct UFitStylePreferencesStorage {
    private enum Storage {
        static let directory = "StylePreferences", guest = "guest.json", pendingSuffix = ".pending.json"
        static let permissions = 0o600
    }
    private struct GuestChoices: Codable { let styleIds: [String] }
    private var directory: URL {
        get throws {
            guard let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
                throw UFitStylePreferencesFailure.storage
            }
            return support.appendingPathComponent(Storage.directory, isDirectory: true)
        }
    }
    func guest() throws -> [String] {
        let file = try directory.appendingPathComponent(Storage.guest)
        guard FileManager.default.fileExists(atPath: file.path) else { return [] }
        let choices = try JSONDecoder().decode(GuestChoices.self, from: Data(contentsOf: file))
        try validateStyleIDs(choices.styleIds)
        return choices.styleIds
    }
    func saveGuest(_ ids: [String]) throws {
        try validateStyleIDs(ids)
        try write(GuestChoices(styleIds: ids), to: directory.appendingPathComponent(Storage.guest))
    }
    func pending(userID: String) throws -> UFitStylePreferencesCommand? {
        let file = try pendingFile(userID)
        guard FileManager.default.fileExists(atPath: file.path) else { return nil }
        let command = try JSONDecoder().decode(UFitStylePreferencesCommand.self, from: Data(contentsOf: file))
        try command.validate(userID: userID)
        return command
    }
    func record(_ command: UFitStylePreferencesCommand) throws {
        try command.validate(userID: command.userID)
        try write(command, to: pendingFile(command.userID))
    }
    func resolve(userID: String) throws {
        let file = try pendingFile(userID)
        if FileManager.default.fileExists(atPath: file.path) { try FileManager.default.removeItem(at: file) }
    }
    private func pendingFile(_ userID: String) throws -> URL {
        guard UUID(uuidString: userID)?.uuidString.lowercased() == userID else { throw UFitStylePreferencesFailure.storage }
        return try directory.appendingPathComponent(userID + Storage.pendingSuffix)
    }
    private func write<Value: Encodable>(_ value: Value, to file: URL) throws {
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(value).write(to: file, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: Storage.permissions], ofItemAtPath: file.path)
    }
}
