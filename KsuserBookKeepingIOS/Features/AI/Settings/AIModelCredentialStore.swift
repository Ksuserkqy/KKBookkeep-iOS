import Foundation
import Security

enum AIModelSettingsError: Error {
    case keychain(OSStatus)
    case invalidEndpoint
    case emptyModelList
}

final class AIModelCredentialStore {
    private let service = "cn.ksuser.bookkeeping.aiModel"
    private let account = "apiKey"

    func readAPIKey() -> String {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard
            status == errSecSuccess,
            let data = result as? Data,
            let value = String(data: data, encoding: .utf8)
        else {
            return ""
        }

        return value
    }

    func saveAPIKey(_ value: String) throws {
        deleteAPIKey()

        guard !value.isEmpty else { return }

        var query = baseQuery()
        query[kSecValueData as String] = Data(value.utf8)
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        query[kSecAttrSynchronizable as String] = kCFBooleanFalse

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw AIModelSettingsError.keychain(status)
        }
    }

    private func deleteAPIKey() {
        SecItemDelete(baseQuery() as CFDictionary)
    }

    private func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}
