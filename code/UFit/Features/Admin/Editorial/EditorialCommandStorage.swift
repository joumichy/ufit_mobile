import Foundation

struct UFitEditorialCommandStorage {
    private enum Storage { static let directory = "EditorialCommands", suffix = ".json", permissions = 0o600 }
    func read(actorID: String) throws -> UFitEditorialCommand? {
        let file = try file(actorID)
        guard FileManager.default.fileExists(atPath: file.path) else { return nil }
        let command = try JSONDecoder().decode(UFitEditorialCommand.self, from: Data(contentsOf: file))
        try command.validate(actorID: actorID); return command
    }
    func record(_ command: UFitEditorialCommand) throws {
        try command.validate(actorID: command.actorID)
        let target = try file(command.actorID)
        try FileManager.default.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(command).write(to: target, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: Storage.permissions], ofItemAtPath: target.path)
    }
    func resolve(actorID: String) throws {
        let target = try file(actorID)
        if FileManager.default.fileExists(atPath: target.path) { try FileManager.default.removeItem(at: target) }
    }
    private func file(_ actorID: String) throws -> URL {
        guard editorialUUID(actorID), let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { throw UFitEditorialFailure.contract }
        return support.appendingPathComponent(Storage.directory, isDirectory: true).appendingPathComponent(actorID + Storage.suffix)
    }
}
