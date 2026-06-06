import Combine
import Foundation

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
