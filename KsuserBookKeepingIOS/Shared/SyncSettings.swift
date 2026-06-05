import Combine
import Foundation
import Security
import SwiftUI

enum SyncProvider: String, CaseIterable, Codable, Identifiable {
    case iCloudDrive
    case webDAV

    var id: String { rawValue }

    var titleKey: LocalizedStringKey {
        switch self {
        case .iCloudDrive:
            return "sync.provider.iCloudDrive"
        case .webDAV:
            return "sync.provider.webDAV"
        }
    }

    var isAvailable: Bool {
        switch self {
        case .iCloudDrive:
            return true
        case .webDAV:
            return true
        }
    }
}

enum WebDAVAuthentication: String, CaseIterable, Codable, Identifiable {
    case password
    case token

    var id: String { rawValue }

    var titleKey: LocalizedStringKey {
        switch self {
        case .password:
            return "sync.webDAV.authentication.password"
        case .token:
            return "sync.webDAV.authentication.token"
        }
    }
}

enum BackupInterval: String, CaseIterable, Codable, Identifiable {
    case oneMinute
    case fiveMinutes
    case tenMinutes

    var id: String { rawValue }

    var timeInterval: TimeInterval {
        switch self {
        case .oneMinute:
            return 60
        case .fiveMinutes:
            return 5 * 60
        case .tenMinutes:
            return 10 * 60
        }
    }

    var titleKey: LocalizedStringKey {
        switch self {
        case .oneMinute:
            return "sync.backupInterval.oneMinute"
        case .fiveMinutes:
            return "sync.backupInterval.fiveMinutes"
        case .tenMinutes:
            return "sync.backupInterval.tenMinutes"
        }
    }
}

enum SyncSetupChoice: String {
    case undecided
    case syncSpace
    case localOnly
}

struct SyncConfiguration: Codable, Equatable {
    var backupEnabled: Bool
    var provider: SyncProvider
    var webDAVAuthentication: WebDAVAuthentication
    var webDAVServerURL: String
    var webDAVUsername: String
    var backupOnChange: Bool
    var autoImport: Bool
    var backupInterval: BackupInterval
    var encryptionEnabled: Bool
    var lastBackupAt: Date?

    static let defaultValue = SyncConfiguration(
        backupEnabled: false,
        provider: .webDAV,
        webDAVAuthentication: .password,
        webDAVServerURL: "",
        webDAVUsername: "",
        backupOnChange: true,
        autoImport: true,
        backupInterval: .tenMinutes,
        encryptionEnabled: true,
        lastBackupAt: nil
    )
}

struct SyncSettingsDraft {
    var configuration: SyncConfiguration
    var password: String
    var accessToken: String
    var encryptionPassword: String
}

struct SyncSecrets {
    var webDAVSecret: String
    var encryptionPassword: String
}

@MainActor
final class SyncSettingsStore: ObservableObject {
    @Published private(set) var configuration: SyncConfiguration
    @Published private(set) var setupChoice: SyncSetupChoice
    @Published private(set) var hasAcceptedLegalTerms: Bool

    private let defaults: UserDefaults
    private let credentialStore = WebDAVCredentialStore()

    private enum DefaultsKey {
        static let configuration = "sync.configuration"
        static let setupChoice = "sync.setupChoice"
        static let hasAcceptedLegalTerms = "onboarding.hasAcceptedLegalTerms"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        let loadedConfiguration: SyncConfiguration
        let hasStoredConfiguration: Bool
        if
            let data = defaults.data(forKey: DefaultsKey.configuration),
            let stored = try? Self.decoder.decode(SyncConfiguration.self, from: data)
        {
            loadedConfiguration = stored
            hasStoredConfiguration = true
        } else {
            loadedConfiguration = .defaultValue
            hasStoredConfiguration = false
        }

        self.configuration = loadedConfiguration
        self.hasAcceptedLegalTerms = defaults.bool(forKey: DefaultsKey.hasAcceptedLegalTerms)

        if
            let rawSetupChoice = defaults.string(forKey: DefaultsKey.setupChoice),
            let setupChoice = SyncSetupChoice(rawValue: rawSetupChoice)
        {
            self.setupChoice = setupChoice
        } else if hasStoredConfiguration {
            self.setupChoice = loadedConfiguration.backupEnabled ? .syncSpace : .localOnly
        } else {
            self.setupChoice = .undecided
        }
    }

    var needsInitialSyncSetup: Bool {
        !hasAcceptedLegalTerms || setupChoice == .undecided
    }

    func makeDraft() -> SyncSettingsDraft {
        SyncSettingsDraft(
            configuration: configuration,
            password: credentialStore.read(account: .password) ?? "",
            accessToken: credentialStore.read(account: .accessToken) ?? "",
            encryptionPassword: credentialStore.read(account: .encryptionPassword) ?? ""
        )
    }

    func save(_ draft: SyncSettingsDraft) throws {
        let data = try Self.encoder.encode(draft.configuration)
        let oldPassword = credentialStore.read(account: .password) ?? ""
        let oldAccessToken = credentialStore.read(account: .accessToken) ?? ""
        let oldEncryptionPassword = credentialStore.read(account: .encryptionPassword) ?? ""

        do {
            try credentialStore.save(draft.password, account: .password)
            try credentialStore.save(draft.accessToken, account: .accessToken)
            try credentialStore.save(draft.encryptionPassword, account: .encryptionPassword)
        } catch {
            try? credentialStore.save(oldPassword, account: .password)
            try? credentialStore.save(oldAccessToken, account: .accessToken)
            try? credentialStore.save(oldEncryptionPassword, account: .encryptionPassword)
            throw error
        }

        defaults.set(data, forKey: DefaultsKey.configuration)
        configuration = draft.configuration
    }

    func completeInitialSetup(_ choice: SyncSetupChoice) {
        defaults.set(choice.rawValue, forKey: DefaultsKey.setupChoice)
        setupChoice = choice
    }

    func acceptLegalTerms() {
        defaults.set(true, forKey: DefaultsKey.hasAcceptedLegalTerms)
        hasAcceptedLegalTerms = true
    }

    func markBackupCompleted(at date: Date = Date()) throws {
        var updatedConfiguration = configuration
        updatedConfiguration.lastBackupAt = date

        let data = try Self.encoder.encode(updatedConfiguration)
        defaults.set(data, forKey: DefaultsKey.configuration)
        configuration = updatedConfiguration
    }

    func secrets(for configuration: SyncConfiguration) -> SyncSecrets {
        let webDAVSecret: String
        switch configuration.webDAVAuthentication {
        case .password:
            webDAVSecret = credentialStore.read(account: .password) ?? ""
        case .token:
            webDAVSecret = credentialStore.read(account: .accessToken) ?? ""
        }

        return SyncSecrets(
            webDAVSecret: webDAVSecret,
            encryptionPassword: credentialStore.read(account: .encryptionPassword) ?? ""
        )
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}

private enum WebDAVCredentialAccount: String {
    case password
    case accessToken
    case encryptionPassword
}

private final class WebDAVCredentialStore {
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

enum SyncSettingsError: Error {
    case keychain(OSStatus)
}
