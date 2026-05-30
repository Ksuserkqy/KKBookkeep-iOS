import Combine
import Foundation

@MainActor
final class ProfileStore: ObservableObject {
    @Published private(set) var profile: PersonalProfile
    @Published private(set) var messageKey: String?

    private let repository: ProfileRepository
    private let syncService: ProfileSyncService

    init() {
        let repository = ProfileRepository()
        self.repository = repository
        self.syncService = ProfileSyncService()
        self.profile = repository.load()
    }

    init(repository: ProfileRepository, syncService: ProfileSyncService) {
        self.repository = repository
        self.syncService = syncService
        self.profile = repository.load()
    }

    func clearMessage() {
        messageKey = nil
    }

    func save(
        displayName: String,
        email: String,
        avatarImageDataBase64: String?,
        currency: ProfileCurrency,
        timeZone: ProfileTimeZone,
        note: String,
        syncConfiguration: SyncConfiguration?,
        syncSecrets: SyncSecrets
    ) async -> Bool {
        var nextProfile = profile
        nextProfile.displayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        nextProfile.email = email.trimmingCharacters(in: .whitespacesAndNewlines)
        nextProfile.avatarImageDataBase64 = avatarImageDataBase64
        nextProfile.currency = currency
        nextProfile.timeZone = timeZone
        nextProfile.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        nextProfile.revision += 1
        nextProfile.updatedAt = Date()
        nextProfile.updatedByDeviceId = DeviceIdentity.currentDeviceId

        do {
            try repository.save(nextProfile)
            profile = nextProfile

            if let syncConfiguration, syncConfiguration.backupEnabled, syncConfiguration.backupOnChange {
                do {
                    try await syncService.backup(profile: nextProfile, configuration: syncConfiguration, secrets: syncSecrets)
                    messageKey = "profile.sync.savedAndBackedUp"
                } catch {
                    messageKey = "profile.sync.error.backupFailed"
                }
            } else {
                messageKey = "profile.sync.savedLocally"
            }

            return true
        } catch {
            messageKey = "profile.sync.error.saveFailed"
            return false
        }
    }

    @discardableResult
    func backupNow(configuration: SyncConfiguration, secrets: SyncSecrets) async -> Bool {
        guard configuration.backupEnabled else {
            messageKey = "profile.sync.error.backupDisabled"
            return false
        }

        do {
            try await syncService.backup(profile: profile, configuration: configuration, secrets: secrets)
            messageKey = "profile.sync.backupSucceeded"
            return true
        } catch {
            messageKey = "profile.sync.error.backupFailed"
            return false
        }
    }

    @discardableResult
    func importNow(configuration: SyncConfiguration, secrets: SyncSecrets) async -> Bool {
        guard configuration.backupEnabled else {
            messageKey = "profile.sync.error.backupDisabled"
            return false
        }

        do {
            guard let remoteProfile = try await syncService.importProfile(configuration: configuration, secrets: secrets) else {
                messageKey = "profile.sync.importNoRemoteProfile"
                return true
            }

            try repository.save(remoteProfile)
            profile = remoteProfile
            messageKey = "profile.sync.importSucceeded"
            return true
        } catch {
            messageKey = "profile.sync.error.importFailed"
            return false
        }
    }

    func importIfRemoteProfileIsNewer(configuration: SyncConfiguration, secrets: SyncSecrets) async {
        guard configuration.backupEnabled else { return }

        do {
            guard let remoteProfile = try await syncService.importProfile(configuration: configuration, secrets: secrets) else {
                return
            }

            guard remoteProfile.isNewer(than: profile) else { return }

            try repository.save(remoteProfile)
            profile = remoteProfile
            messageKey = "profile.sync.importSucceeded"
        } catch {
            return
        }
    }

    func testSyncLocation(configuration: SyncConfiguration, secrets: SyncSecrets) async {
        guard configuration.backupEnabled else {
            messageKey = "profile.sync.error.backupDisabled"
            return
        }

        do {
            try await syncService.testConnection(configuration: configuration, secrets: secrets)
            messageKey = "profile.sync.testSucceeded"
        } catch {
            messageKey = "profile.sync.error.testFailed"
        }
    }
}

struct ProfileRepository {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func load() -> PersonalProfile {
        guard
            let data = try? Data(contentsOf: profileURL()),
            let document = try? Self.decoder.decode(PersonalProfileSyncDocument.self, from: data)
        else {
            return .empty()
        }

        return document.profile
    }

    func save(_ profile: PersonalProfile) throws {
        let fileURL = profileURL()
        try fileManager.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let data = try Self.encoder.encode(PersonalProfileSyncDocument(profile: profile))
        try data.write(to: fileURL, options: [.atomic, .completeFileProtection])
    }

    private func profileURL() -> URL {
        let baseURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return baseURL
            .appendingPathComponent("KKBookkeep", isDirectory: true)
            .appendingPathComponent("Profile", isDirectory: true)
            .appendingPathComponent("personal-profile.json")
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}

struct ProfileSyncService {
    private let profilePath = "KKBookKeep/v1/profile/personal-profile.json"

    func backup(profile: PersonalProfile, configuration: SyncConfiguration, secrets: SyncSecrets) async throws {
        let storage = try SyncStorageFactory.storage(for: configuration, webDAVSecret: secrets.webDAVSecret)
        var data = try Self.encoder.encode(PersonalProfileSyncDocument(profile: profile))

        if configuration.encryptionEnabled {
            data = try SyncFileEncryption.encrypt(data, password: secrets.encryptionPassword)
        }

        try await storage.writeFileAtomic(data, to: profilePath)
    }

    func importProfile(configuration: SyncConfiguration, secrets: SyncSecrets) async throws -> PersonalProfile? {
        let storage = try SyncStorageFactory.storage(for: configuration, webDAVSecret: secrets.webDAVSecret)

        do {
            let remoteData = try await storage.readFile(at: profilePath)
            let data = try SyncFileEncryption.decryptIfNeeded(remoteData, password: secrets.encryptionPassword)
            return try Self.decoder.decode(PersonalProfileSyncDocument.self, from: data).profile
        } catch SyncStorageError.fileNotFound {
            return nil
        }
    }

    func testConnection(configuration: SyncConfiguration, secrets: SyncSecrets) async throws {
        let storage = try SyncStorageFactory.storage(for: configuration, webDAVSecret: secrets.webDAVSecret)
        let testPath = "KKBookKeep/v1/profile/.connection-test.json"
        try await storage.writeFileAtomic(Data("{\"ok\":true}".utf8), to: testPath)
        try await storage.deleteFile(at: testPath)
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
