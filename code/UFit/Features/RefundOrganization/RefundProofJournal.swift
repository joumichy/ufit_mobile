import Foundation

struct UFitRefundProofJournal {
    let actorID: String
    let reference: UFitRefundRecoveryReference
    private struct Record: Codable {let actorID: String; let reference: UFitRefundRecoveryReference; let request: UFitRefundProofRequest}
    private enum Storage {static let directory = "RefundProofRequests", archives = "Unreadable", separator = "-", suffix = "json", permissions = 0o600}
    func read() throws -> UFitRefundProofRequest? {
        let target = try file()
        guard FileManager.default.fileExists(atPath: target.path) else {return nil}
        let record = try JSONDecoder().decode(Record.self, from: Data(contentsOf: target))
        guard record.actorID == actorID, record.reference == reference else {throw UFitRefundProofFailure.local}
        try record.request.validate(); return record.request
    }
    func write(_ request: UFitRefundProofRequest) throws {
        try request.validate(); let target = try file()
        try FileManager.default.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(Record(actorID: actorID, reference: reference, request: request)).write(to: target, options: [.atomic, .completeFileProtectionUnlessOpen])
        try FileManager.default.setAttributes([.posixPermissions: Storage.permissions], ofItemAtPath: target.path)
    }
    func resolve() throws {let target = try file(); if FileManager.default.fileExists(atPath: target.path) {try FileManager.default.removeItem(at: target)}}
    func archiveUnreadable() throws {
        let target = try file(); guard FileManager.default.fileExists(atPath: target.path) else {return}
        let directory = target.deletingLastPathComponent().appendingPathComponent(Storage.archives, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try FileManager.default.moveItem(at: target, to: directory.appendingPathComponent(UUID().uuidString).appendingPathExtension(Storage.suffix))
    }
    private func file() throws -> URL {
        guard UUID(uuidString: actorID) != nil, UUID(uuidString: reference.id) != nil, let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {throw UFitRefundProofFailure.local}
        return support.appendingPathComponent(Storage.directory, isDirectory: true).appendingPathComponent(actorID + Storage.separator + reference.kind.rawValue + Storage.separator + reference.id).appendingPathExtension(Storage.suffix)
    }
}
