import Foundation
import Security

enum SyncSettingsError: Error {
    case keychain(OSStatus)
}

enum WebDAVCredentialAccount: String {
    case password
    case accessToken
    case encryptionPassword
}

final class WebDAVCredentialStore {
    private let service = "cn.ksuser.bookkeeping.webDAV"

    func read(account: WebDAVCredentialAccount) -> String? {
        var query = baseQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard
            status == errSecSuccess,
            let data = result as? Data
        else {
            return nil
        }

        return String(data: data, encoding: .utf8)
    }

    func save(_ value: String, account: WebDAVCredentialAccount) throws {
        delete(account: account)

        guard !value.isEmpty else { return }

        var query = baseQuery(account: account)
        query[kSecValueData as String] = Data(value.utf8)
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        query[kSecAttrSynchronizable as String] = kCFBooleanFalse

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw SyncSettingsError.keychain(status)
        }
    }

    private func delete(account: WebDAVCredentialAccount) {
        SecItemDelete(baseQuery(account: account) as CFDictionary)
    }

    private func baseQuery(account: WebDAVCredentialAccount) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account.rawValue
        ]
    }
}
