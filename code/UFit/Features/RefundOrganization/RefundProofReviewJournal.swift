import Foundation

struct UFitRefundProofReviewJournal {
    let actorID: String
    let reference: UFitRefundRecoveryReference
    private struct Record: Codable {let actorID: String; let reference: UFitRefundRecoveryReference; let request: UFitRefundProofReviewRequest}
    private enum Storage {static let directory = "RefundProofReviewRequests", archive = "Unreadable", separator = "-", suffix = "json", permissions = 0o600}
    func read() throws -> UFitRefundProofReviewRequest? {
        let url = try file(); guard FileManager.default.fileExists(atPath: url.path) else {return nil}
        let record = try JSONDecoder().decode(Record.self, from: Data(contentsOf: url))
        guard record.actorID == actorID, record.reference == reference else {throw UFitRefundOrganizationFailure.localRecord}
        try record.request.validate(); return record.request
    }
    func write(_ request: UFitRefundProofReviewRequest) throws {
        try request.validate(); let url = try file()
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(Record(actorID: actorID, reference: reference, request: request)).write(to: url, options: [.atomic, .completeFileProtectionUnlessOpen])
        try FileManager.default.setAttributes([.posixPermissions: Storage.permissions], ofItemAtPath: url.path)
    }
    func resolve() throws {let url = try file(); if FileManager.default.fileExists(atPath: url.path) {try FileManager.default.removeItem(at: url)}}
    func archiveUnreadable() throws {
        let url = try file(); guard FileManager.default.fileExists(atPath: url.path) else {return}
        let directory = url.deletingLastPathComponent().appendingPathComponent(Storage.archive, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try FileManager.default.moveItem(at: url, to: directory.appendingPathComponent(UUID().uuidString).appendingPathExtension(Storage.suffix))
    }
    private func file() throws -> URL {
        guard UUID(uuidString: actorID) != nil, UUID(uuidString: reference.id) != nil,
              let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {throw UFitRefundOrganizationFailure.localRecord}
        return support.appendingPathComponent(Storage.directory, isDirectory: true).appendingPathComponent(actorID + Storage.separator + reference.kind.rawValue + Storage.separator + reference.id).appendingPathExtension(Storage.suffix)
    }
}
