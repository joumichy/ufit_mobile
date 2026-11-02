import Foundation
import Security

/// The receipt survives authentication removal and never stores an access token.
@MainActor
final class UFitAccountDeletionKeychain {
    private enum Entry { static let service = "com.stellark.ufit.account-deletion", account = "request", synchronizable = false }
    private var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: Entry.service,
         kSecAttrAccount as String: Entry.account, kSecAttrSynchronizable as String: Entry.synchronizable]
    }
    func read() throws -> UFitAccountDeletionRequest? {
        var lookup = query
        lookup[kSecReturnData as String] = true; lookup[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(lookup as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else { throw UFitAccountDeletionFailure.storage }
        do { let value = try JSONDecoder().decode(UFitAccountDeletionRequest.self, from: data); try value.validate(); return value }
        catch { throw UFitAccountDeletionFailure.storage }
    }
    func save(_ request: UFitAccountDeletionRequest) throws {
        try request.validate()
        let data = try JSONEncoder().encode(request)
        let status = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecSuccess { return }
        guard status == errSecItemNotFound else { throw UFitAccountDeletionFailure.storage }
        var insertion = query
        insertion[kSecValueData as String] = data
        insertion[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        guard SecItemAdd(insertion as CFDictionary, nil) == errSecSuccess else { throw UFitAccountDeletionFailure.storage }
    }
    func clear() throws {
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw UFitAccountDeletionFailure.storage }
    }
}
