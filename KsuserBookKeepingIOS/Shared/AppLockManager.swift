import Combine
import CryptoKit
import Foundation
import LocalAuthentication
import Security
import SwiftUI

final class AppLockManager: ObservableObject {
    @Published private(set) var isLocked: Bool
    @Published private(set) var isPasswordEnabled: Bool
    @Published private(set) var isBiometricUnlockEnabled: Bool
    @Published private(set) var isBiometricAvailable = false
    @Published private(set) var messageKey: String?

    private let defaults: UserDefaults
    private let passwordStore = LocalPasswordStore()

    private enum DefaultsKey {
        static let passwordEnabled = "security.appLock.passwordEnabled"
        static let biometricUnlockEnabled = "security.appLock.biometricUnlockEnabled"
    }

    @MainActor
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        let hasPassword = passwordStore.hasPassword()
        let passwordEnabled = defaults.bool(forKey: DefaultsKey.passwordEnabled) && hasPassword
        let biometricEnabled = defaults.bool(forKey: DefaultsKey.biometricUnlockEnabled) && passwordEnabled

        self.isPasswordEnabled = passwordEnabled
        self.isBiometricUnlockEnabled = biometricEnabled
        self.isLocked = passwordEnabled

        refreshBiometricAvailability()
    }

    @MainActor
    func refreshConfiguration() {
        let hasPassword = passwordStore.hasPassword()
        isPasswordEnabled = defaults.bool(forKey: DefaultsKey.passwordEnabled) && hasPassword
        isBiometricUnlockEnabled = defaults.bool(forKey: DefaultsKey.biometricUnlockEnabled) && isPasswordEnabled

        if !isPasswordEnabled {
            isLocked = false
        }

        refreshBiometricAvailability()
    }

    @MainActor
    func lockIfNeeded() {
        refreshConfiguration()

        if isPasswordEnabled {
            isLocked = true
            messageKey = nil
        }
    }

    @MainActor
    func unlock(with password: String) {
        guard passwordStore.verify(password) else {
            messageKey = "appLock.error.wrongPassword"
            return
        }

        isLocked = false
        messageKey = nil
    }

    @MainActor
    func savePassword(_ password: String) throws {
        try passwordStore.save(password)
        defaults.set(true, forKey: DefaultsKey.passwordEnabled)
        isPasswordEnabled = true
        isLocked = false
        messageKey = nil
        refreshBiometricAvailability()
    }

    @MainActor
    func disablePasswordLock() {
        passwordStore.delete()
        defaults.set(false, forKey: DefaultsKey.passwordEnabled)
        defaults.set(false, forKey: DefaultsKey.biometricUnlockEnabled)
        isPasswordEnabled = false
        isBiometricUnlockEnabled = false
        isLocked = false
        messageKey = nil
    }

    @MainActor
    func disableBiometricUnlock() {
        defaults.set(false, forKey: DefaultsKey.biometricUnlockEnabled)
        isBiometricUnlockEnabled = false
        messageKey = nil
    }

    @MainActor
    func enableBiometricUnlock(reason: String) {
        guard isPasswordEnabled, isBiometricAvailable else {
            messageKey = "settings.security.error.biometricUnavailable"
            disableBiometricUnlock()
            return
        }

        let context = LAContext()
        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { [weak self] success, _ in
            Task { @MainActor in
                guard let self else { return }

                if success {
                    self.defaults.set(true, forKey: DefaultsKey.biometricUnlockEnabled)
                    self.isBiometricUnlockEnabled = true
                    self.messageKey = nil
                } else {
                    self.disableBiometricUnlock()
                    self.messageKey = "settings.security.error.biometricFailed"
                }
            }
        }
    }

    @MainActor
    func unlockWithBiometrics(reason: String) {
        guard isPasswordEnabled, isBiometricUnlockEnabled, isBiometricAvailable else {
            messageKey = "settings.security.error.biometricUnavailable"
            return
        }

        let context = LAContext()
        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { [weak self] success, _ in
            Task { @MainActor in
                guard let self else { return }

                if success {
                    self.isLocked = false
                    self.messageKey = nil
                } else {
                    self.messageKey = "appLock.error.biometricFailed"
                }
            }
        }
    }

    @MainActor
    private func refreshBiometricAvailability() {
        let context = LAContext()
        var error: NSError?
        isBiometricAvailable = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)

        if !isBiometricAvailable {
            defaults.set(false, forKey: DefaultsKey.biometricUnlockEnabled)
            isBiometricUnlockEnabled = false
        }
    }
}

private struct StoredPassword: Codable {
    let salt: String
    let digest: String
}

private final class LocalPasswordStore {
    private let service = "cn.ksuser.bookkeeping.localAppLock"
    private let account = "appLockPasswordHash"

    func hasPassword() -> Bool {
        var query = baseQuery()
        query[kSecReturnData as String] = false
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        return SecItemCopyMatching(query as CFDictionary, nil) == errSecSuccess
    }

    func save(_ password: String) throws {
        let salt = try makeSalt()
        let digest = Self.digest(password: password, salt: salt)
        let record = StoredPassword(
            salt: salt.base64EncodedString(),
            digest: digest.base64EncodedString()
        )
        let data = try JSONEncoder().encode(record)

        delete()

        var query = baseQuery()
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        query[kSecAttrSynchronizable as String] = kCFBooleanFalse

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw LocalPasswordStoreError.keychain(status)
        }
    }

    func verify(_ password: String) -> Bool {
        guard
            let data = readData(),
            let record = try? JSONDecoder().decode(StoredPassword.self, from: data),
            let salt = Data(base64Encoded: record.salt),
            let expectedDigest = Data(base64Encoded: record.digest)
        else {
            return false
        }

        let actualDigest = Self.digest(password: password, salt: salt)
        return Self.constantTimeEqual(actualDigest, expectedDigest)
    }

    func delete() {
        SecItemDelete(baseQuery() as CFDictionary)
    }

    private func readData() -> Data? {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else { return nil }

        return result as? Data
    }

    private func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }

    private func makeSalt() throws -> Data {
        var bytes = [UInt8](repeating: 0, count: 16)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        guard status == errSecSuccess else {
            throw LocalPasswordStoreError.randomGenerationFailed
        }

        return Data(bytes)
    }

    private static func digest(password: String, salt: Data) -> Data {
        var input = Data(password.utf8)
        input.append(salt)

        return Data(SHA256.hash(data: input))
    }

    private static func constantTimeEqual(_ lhs: Data, _ rhs: Data) -> Bool {
        guard lhs.count == rhs.count else { return false }

        var difference: UInt8 = 0
        for (left, right) in zip(lhs, rhs) {
            difference |= left ^ right
        }

        return difference == 0
    }
}

private enum LocalPasswordStoreError: Error {
    case keychain(OSStatus)
    case randomGenerationFailed
}
