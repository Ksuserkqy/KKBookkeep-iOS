import Foundation

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
