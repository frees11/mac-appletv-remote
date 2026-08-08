import Foundation
import Security

public final class CredentialsManager: CredentialsManagerProtocol, Sendable {
    private let serviceName = "com.atvremote.credentials"

    public init() {}

    public func save(_ credentials: PairingCredentials) throws {
        let data = try JSONEncoder().encode(credentials)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: credentials.deviceId,
        ]

        SecItemDelete(query as CFDictionary)

        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: credentials.deviceId,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked,
        ]

        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw CredentialsError.saveFailed(status)
        }
    }

    public func load(for deviceId: String) throws -> PairingCredentials? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: deviceId,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data else {
            if status == errSecItemNotFound {
                return nil
            }
            throw CredentialsError.loadFailed(status)
        }

        return try JSONDecoder().decode(PairingCredentials.self, from: data)
    }

    public func delete(for deviceId: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: deviceId,
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw CredentialsError.deleteFailed(status)
        }
    }

    public func listAllDeviceIds() throws -> [String] {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                return []
            }
            throw CredentialsError.loadFailed(status)
        }

        guard let items = result as? [[String: Any]] else {
            return []
        }

        return items.compactMap { $0[kSecAttrAccount as String] as? String }
    }

    public func hasPairing(for deviceId: String) -> Bool {
        (try? load(for: deviceId)) != nil
    }
}

public enum CredentialsError: Error, LocalizedError {
    case saveFailed(OSStatus)
    case loadFailed(OSStatus)
    case deleteFailed(OSStatus)

    public var errorDescription: String? {
        switch self {
        case .saveFailed(let status):
            return "Failed to save credentials: \(status)"
        case .loadFailed(let status):
            return "Failed to load credentials: \(status)"
        case .deleteFailed(let status):
            return "Failed to delete credentials: \(status)"
        }
    }
}
