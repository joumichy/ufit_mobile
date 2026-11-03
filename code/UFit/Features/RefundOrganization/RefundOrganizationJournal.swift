import Foundation

struct UFitRefundOrganizationJournal {
    let actorID: String
    let scope: UFitRefundOrganizationScope
    let reference: UFitRefundRecoveryReference
    private struct Record: Codable {
        let actorID: String
        let scope: UFitRefundOrganizationScope
        let reference: UFitRefundRecoveryReference
        let request: UFitRefundOrganizationRequest
    }
    private enum Storage {static let directory = "RefundOrganizationRequests", separator = "-", suffix = "json", archives = "Unreadable", permissions = 0o600}
    func read() throws -> UFitRefundOrganizationRequest? {
        let target = try file()
        guard FileManager.default.fileExists(atPath: target.path) else {return nil}
        let record = try JSONDecoder().decode(Record.self, from: Data(contentsOf: target))
        guard record.actorID == actorID, record.scope == scope, record.reference == reference else {throw UFitRefundOrganizationFailure.localRecord}
        try validate(record.request); return record.request
    }
    func record(_ request: UFitRefundOrganizationRequest) throws {
        try validate(request)
        let target = try file()
        try FileManager.default.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(Record(actorID: actorID, scope: scope, reference: reference, request: request)).write(to: target, options: [.atomic, .completeFileProtectionUnlessOpen])
        try FileManager.default.setAttributes([.posixPermissions: Storage.permissions], ofItemAtPath: target.path)
    }
    func resolve() throws {
        let target = try file()
        if FileManager.default.fileExists(atPath: target.path) {try FileManager.default.removeItem(at: target)}
    }
    func archiveUnreadable() throws {
        let target = try file()
        guard FileManager.default.fileExists(atPath: target.path) else {return}
        let directory = target.deletingLastPathComponent().appendingPathComponent(Storage.archives, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try FileManager.default.moveItem(at: target, to: directory.appendingPathComponent(UUID().uuidString).appendingPathExtension(Storage.suffix))
    }
    private func validate(_ request: UFitRefundOrganizationRequest) throws {
        try request.validate()
        guard (scope == .administrator && request.action == .arrange) || (scope == .customer && request.action == .provideDetails) else {throw UFitRefundOrganizationFailure.localRecord}
    }
    private func file() throws -> URL {
        guard UUID(uuidString: actorID) != nil, UUID(uuidString: reference.id) != nil,
              let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {throw UFitRefundOrganizationFailure.localRecord}
        return support.appendingPathComponent(Storage.directory, isDirectory: true).appendingPathComponent(actorID + Storage.separator + scope.rawValue + Storage.separator + reference.kind.rawValue + Storage.separator + reference.id).appendingPathExtension(Storage.suffix)
    }
}
