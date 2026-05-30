import Foundation

struct BookkeepingMetadataSyncDocument: Codable, Equatable {
    let schemaVersion: Int
    let entity: String
    var ledgerId: String
    var revision: Int
    var updatedAt: Date
    var updatedByDeviceId: String
    var accounts: [DraftAccount]
    var categories: [DraftCategory]

    init(
        ledgerId: String = "default",
        revision: Int,
        updatedAt: Date,
        updatedByDeviceId: String,
        accounts: [DraftAccount],
        categories: [DraftCategory]
    ) {
        self.schemaVersion = 1
        self.entity = "bookkeepingMetadata"
        self.ledgerId = ledgerId
        self.revision = revision
        self.updatedAt = updatedAt
        self.updatedByDeviceId = updatedByDeviceId
        self.accounts = accounts
        self.categories = categories
    }

    func isNewer(than other: BookkeepingMetadataSyncDocument) -> Bool {
        if updatedAt != other.updatedAt {
            return updatedAt > other.updatedAt
        }

        if revision != other.revision {
            return revision > other.revision
        }

        return updatedByDeviceId > other.updatedByDeviceId
    }
}

struct BookkeepingMetadataSyncService {
    private let metadataPath = "KKBookKeep/v1/ledgers/default/accounts-categories.json"

    func backup(document: BookkeepingMetadataSyncDocument, configuration: SyncConfiguration, secrets: SyncSecrets) async throws {
        let storage = try SyncStorageFactory.storage(for: configuration, webDAVSecret: secrets.webDAVSecret)
        var data = try Self.encoder.encode(document)

        if configuration.encryptionEnabled {
            data = try SyncFileEncryption.encrypt(data, password: secrets.encryptionPassword)
        }

        try await storage.writeFileAtomic(data, to: metadataPath)
    }

    func importDocument(configuration: SyncConfiguration, secrets: SyncSecrets) async throws -> BookkeepingMetadataSyncDocument? {
        let storage = try SyncStorageFactory.storage(for: configuration, webDAVSecret: secrets.webDAVSecret)

        do {
            let remoteData = try await storage.readFile(at: metadataPath)
            let data = try SyncFileEncryption.decryptIfNeeded(remoteData, password: secrets.encryptionPassword)
            return try Self.decoder.decode(BookkeepingMetadataSyncDocument.self, from: data)
        } catch SyncStorageError.fileNotFound {
            return nil
        }
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
