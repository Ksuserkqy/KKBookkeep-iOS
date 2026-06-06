import Foundation

struct ProfileSyncService {
    static let opsPerFile = 100

    private let profilePath = "KKBookKeep/v1/profile/personal-profile.json"
    private let profileOpsDirectory = "KKBookKeep/v1/profile-devices"
    private let logService = JSONLSyncLogService<PersonalProfileOp>()

    func backup(profile: PersonalProfile, configuration: SyncConfiguration, secrets: SyncSecrets) async throws {
        let storage = try SyncStorageFactory.storage(for: configuration, webDAVSecret: secrets.webDAVSecret)
        var data = try Self.encoder.encode(PersonalProfileSyncDocument(profile: profile))

        if configuration.encryptionEnabled {
            data = try SyncFileEncryption.encrypt(data, password: secrets.encryptionPassword)
        }

        try await storage.writeFileAtomic(data, to: profilePath)
    }

    func backup(ops: [PersonalProfileOp], configuration: SyncConfiguration, secrets: SyncSecrets) async throws {
        try await logService.backup(
            ops: ops,
            configuration: configuration,
            secrets: secrets,
            descriptor: descriptor
        )
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

    func importOps(configuration: SyncConfiguration, secrets: SyncSecrets) async throws -> [PersonalProfileOp] {
        try await logService.importRemoteOps(
            configuration: configuration,
            secrets: secrets,
            descriptor: descriptor
        )
    }

    func testConnection(configuration: SyncConfiguration, secrets: SyncSecrets) async throws {
        let storage = try SyncStorageFactory.storage(for: configuration, webDAVSecret: secrets.webDAVSecret)
        let testPath = "KKBookKeep/v1/profile/.connection-test.json"
        try await storage.writeFileAtomic(Data("{\"ok\":true}".utf8), to: testPath)
        try await storage.deleteFile(at: testPath)
    }

    private var descriptor: SyncLogDescriptor {
        SyncLogDescriptor(
            domain: .profile,
            remoteDirectory: profileOpsDirectory,
            opsPerFile: Self.opsPerFile
        )
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
