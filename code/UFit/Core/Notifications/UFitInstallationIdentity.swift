import Foundation
import CryptoKit
import Security

struct UFitInstallationOperation: Codable {
    let id: String, tokenDigest: String, eventID: UUID
    let version: Int
    let environment: UFitPushEnvironment
}
struct UFitInstallationBinding: Codable {
    let id: String, userID: String, authSessionID: String
    var operation: UFitInstallationOperation?
}
struct UFitInstallationIdentity: Codable {
    let id: String, proof: String
    var binding: UFitInstallationBinding?
    var pendingDetachments: [String]
    private enum Encoding {
        static let hexByte = "%02x", secretBytes = 32, digestCharacters = 64
        static let alphabet = CharacterSet(charactersIn: "0123456789abcdef")
    }
    static func create() throws -> Self {
        var bytes = [UInt8](repeating: .zero, count: Encoding.secretBytes)
        guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else { throw UFitInstallationFailure.storage }
        return Self(id: UUID().uuidString.lowercased(), proof: hex(Data(bytes)), binding: nil, pendingDetachments: [])
    }
    static func hex(_ data: Data) -> String { data.map { String(format: Encoding.hexByte, $0) }.joined() }
    static func digest(_ value: String) -> String { hex(Data(SHA256.hash(data: Data(value.utf8)))) }
    private static func validDigest(_ value: String) -> Bool {
        value.count == Encoding.digestCharacters && value.unicodeScalars.allSatisfy(Encoding.alphabet.contains)
    }
    func validate() throws {
        guard UFitInstallationHTTP.identifier(id), Self.validDigest(proof),
              Set(pendingDetachments).count == pendingDetachments.count, pendingDetachments.allSatisfy(UFitInstallationHTTP.identifier) else { throw UFitInstallationFailure.storage }
        if let binding {
            guard UFitInstallationHTTP.identifier(binding.id), UFitInstallationHTTP.identifier(binding.userID),
                  UFitInstallationHTTP.identifier(binding.authSessionID), !pendingDetachments.contains(binding.id) else { throw UFitInstallationFailure.storage }
            if let operation = binding.operation {
                guard UFitInstallationHTTP.identifier(operation.id), Self.validDigest(operation.tokenDigest),
                      (UFitInstallationHTTP.absentVersion..<UFitInstallationHTTP.maximumVersion).contains(operation.version) else { throw UFitInstallationFailure.storage }
            }
        }
    }
}
@MainActor
final class UFitInstallationKeychain {
    private enum Entry { static let service = "com.stellark.ufit.notifications", account = "installation", synchronizable = false }
    private var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: Entry.service,
         kSecAttrAccount as String: Entry.account, kSecAttrSynchronizable as String: Entry.synchronizable]
    }
    func read() throws -> UFitInstallationIdentity? {
        var lookup = query
        lookup[kSecReturnData as String] = true; lookup[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(lookup as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else { throw UFitInstallationFailure.storage }
        do { let value = try JSONDecoder().decode(UFitInstallationIdentity.self, from: data); try value.validate(); return value }
        catch { throw UFitInstallationFailure.storage }
    }
    func save(_ identity: UFitInstallationIdentity) throws {
        try identity.validate()
        let data = try JSONEncoder().encode(identity)
        let update = [kSecValueData as String: data]
        let status = SecItemUpdate(query as CFDictionary, update as CFDictionary)
        if status == errSecSuccess { return }
        guard status == errSecItemNotFound else { throw UFitInstallationFailure.storage }
        var insertion = query
        insertion[kSecValueData as String] = data
        insertion[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        guard SecItemAdd(insertion as CFDictionary, nil) == errSecSuccess else { throw UFitInstallationFailure.storage }
    }
}
