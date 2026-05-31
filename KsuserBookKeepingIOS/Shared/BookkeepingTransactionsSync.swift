import Foundation

struct BookkeepingTransactionsSyncDocument: Codable, Equatable {
    let schemaVersion: Int
    let entity: String
    var ledgerId: String
    var revision: Int
    var updatedAt: Date
    var updatedByDeviceId: String
    var transactions: [DraftTransaction]

    init(
        ledgerId: String = "default",
        revision: Int,
        updatedAt: Date,
        updatedByDeviceId: String,
        transactions: [DraftTransaction]
    ) {
        self.schemaVersion = 1
        self.entity = "bookkeepingTransactions"
        self.ledgerId = ledgerId
        self.revision = revision
        self.updatedAt = updatedAt
        self.updatedByDeviceId = updatedByDeviceId
        self.transactions = transactions
    }

    func isNewer(than other: BookkeepingTransactionsSyncDocument) -> Bool {
        if updatedAt != other.updatedAt {
            return updatedAt > other.updatedAt
        }

        if revision != other.revision {
            return revision > other.revision
        }

        return updatedByDeviceId > other.updatedByDeviceId
    }
}

struct BookkeepingTransactionsSyncService {
    private let transactionsPath = "KKBookKeep/v1/ledgers/default/transactions.json"

    func backup(document: BookkeepingTransactionsSyncDocument, configuration: SyncConfiguration, secrets: SyncSecrets) async throws {
        let storage = try SyncStorageFactory.storage(for: configuration, webDAVSecret: secrets.webDAVSecret)
        var data = try Self.encoder.encode(document)

        if configuration.encryptionEnabled {
            data = try SyncFileEncryption.encrypt(data, password: secrets.encryptionPassword)
        }

        try await storage.writeFileAtomic(data, to: transactionsPath)
    }

    func importDocument(configuration: SyncConfiguration, secrets: SyncSecrets) async throws -> BookkeepingTransactionsSyncDocument? {
        let storage = try SyncStorageFactory.storage(for: configuration, webDAVSecret: secrets.webDAVSecret)

        do {
            let remoteData = try await storage.readFile(at: transactionsPath)
            let data = try SyncFileEncryption.decryptIfNeeded(remoteData, password: secrets.encryptionPassword)
            return try Self.decoder.decode(BookkeepingTransactionsSyncDocument.self, from: data)
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
