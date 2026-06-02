import Foundation

enum BookkeepingTransactionOpAction: String, Codable {
    case create
    case update
    case delete
}

struct BookkeepingTransactionOp: Codable, Equatable, Identifiable {
    let schemaVersion: Int
    var opId: String
    var ledgerId: String
    var deviceId: String
    var seq: Int
    var entity: String
    var entityId: String
    var action: BookkeepingTransactionOpAction
    var occurredAt: Date
    var createdAt: Date
    var payload: DraftTransaction?

    var id: String { opId }

    init(
        opId: String = UUID().uuidString,
        ledgerId: String = "default",
        deviceId: String,
        seq: Int,
        entityId: String,
        action: BookkeepingTransactionOpAction,
        occurredAt: Date,
        createdAt: Date = Date(),
        payload: DraftTransaction?
    ) {
        self.schemaVersion = 1
        self.opId = opId
        self.ledgerId = ledgerId
        self.deviceId = deviceId
        self.seq = seq
        self.entity = "transaction"
        self.entityId = entityId
        self.action = action
        self.occurredAt = occurredAt
        self.createdAt = createdAt
        self.payload = payload
    }

    var fileIndex: Int {
        max(0, (seq - 1) / BookkeepingTransactionsSyncService.opsPerFile)
    }

    var sortKey: TransactionOpSortKey {
        TransactionOpSortKey(occurredAt: occurredAt, deviceId: deviceId, seq: seq)
    }
}

struct TransactionOpSortKey: Codable, Equatable, Comparable {
    var occurredAt: Date
    var deviceId: String
    var seq: Int

    static let zero = TransactionOpSortKey(
        occurredAt: Date(timeIntervalSince1970: 0),
        deviceId: "",
        seq: 0
    )

    static func < (lhs: TransactionOpSortKey, rhs: TransactionOpSortKey) -> Bool {
        if lhs.occurredAt != rhs.occurredAt {
            return lhs.occurredAt < rhs.occurredAt
        }

        if lhs.deviceId != rhs.deviceId {
            return lhs.deviceId < rhs.deviceId
        }

        return lhs.seq < rhs.seq
    }
}

struct BookkeepingTransactionsSyncDocument: Codable, Equatable {
    let schemaVersion: Int
    let entity: String
    var ledgerId: String
    var revision: Int
    var updatedAt: Date
    var updatedByDeviceId: String
    var transactions: [DraftTransaction]
}

struct BookkeepingTransactionsSyncService {
    static let opsPerFile = 100

    private let ledgerPath = "KKBookKeep/v1/ledgers/default"
    private let legacyTransactionsPath = "KKBookKeep/v1/ledgers/default/transactions.json"

    func backup(ops: [BookkeepingTransactionOp], configuration: SyncConfiguration, secrets: SyncSecrets) async throws {
        guard !ops.isEmpty else { return }

        let storage = try SyncStorageFactory.storage(for: configuration, webDAVSecret: secrets.webDAVSecret)
        let groupedOps = Dictionary(grouping: ops) { op in
            opFileName(for: op.seq)
        }

        for (fileName, fileOps) in groupedOps {
            let sortedOps = fileOps.sorted(by: Self.opSort)
            var data = try Self.encodeJSONL(sortedOps)

            if configuration.encryptionEnabled {
                data = try SyncFileEncryption.encrypt(data, password: secrets.encryptionPassword)
            }

            let deviceId = sortedOps.first?.deviceId ?? DeviceIdentity.currentDeviceId
            try await storage.writeFileAtomic(data, to: "\(devicePath(for: deviceId))/\(fileName)")
        }
    }

    func importRemoteOps(configuration: SyncConfiguration, secrets: SyncSecrets) async throws -> [BookkeepingTransactionOp] {
        let storage = try SyncStorageFactory.storage(for: configuration, webDAVSecret: secrets.webDAVSecret)
        let devicesPath = "\(ledgerPath)/devices"
        let deviceIds: [String]

        do {
            deviceIds = try await storage.listDirectories(at: devicesPath)
        } catch SyncStorageError.fileNotFound {
            return []
        }

        var importedOps: [BookkeepingTransactionOp] = []
        for deviceId in deviceIds {
            let path = "\(devicesPath)/\(deviceId)"
            let files: [String]
            do {
                files = try await storage.listFiles(at: path)
            } catch SyncStorageError.fileNotFound {
                continue
            }

            for file in files where file.hasSuffix(".jsonl") {
                let remoteData = try await storage.readFile(at: "\(path)/\(file)")
                let data = try SyncFileEncryption.decryptIfNeeded(remoteData, password: secrets.encryptionPassword)
                importedOps.append(contentsOf: try Self.decodeJSONL(data))
            }
        }

        return importedOps.sorted(by: Self.opSort)
    }

    func importLegacyTransactions(configuration: SyncConfiguration, secrets: SyncSecrets) async throws -> [DraftTransaction]? {
        let storage = try SyncStorageFactory.storage(for: configuration, webDAVSecret: secrets.webDAVSecret)

        do {
            let remoteData = try await storage.readFile(at: legacyTransactionsPath)
            let data = try SyncFileEncryption.decryptIfNeeded(remoteData, password: secrets.encryptionPassword)
            return try Self.decoder.decode(BookkeepingTransactionsSyncDocument.self, from: data).transactions
        } catch SyncStorageError.fileNotFound {
            return nil
        }
    }

    private func devicePath(for deviceId: String) -> String {
        "\(ledgerPath)/devices/\(deviceId)"
    }

    private func opFileName(for seq: Int) -> String {
        let start = ((seq - 1) / Self.opsPerFile) * Self.opsPerFile + 1
        let end = start + Self.opsPerFile - 1
        return "\(Self.seqFormatter.string(from: NSNumber(value: start)) ?? "\(start)")-\(Self.seqFormatter.string(from: NSNumber(value: end)) ?? "\(end)").jsonl"
    }

    private static func encodeJSONL(_ ops: [BookkeepingTransactionOp]) throws -> Data {
        let lines = try ops.map { op in
            String(data: try encoder.encode(op), encoding: .utf8) ?? "{}"
        }

        return Data((lines.joined(separator: "\n") + "\n").utf8)
    }

    private static func decodeJSONL(_ data: Data) throws -> [BookkeepingTransactionOp] {
        guard let text = String(data: data, encoding: .utf8) else { return [] }

        return try text
            .split(whereSeparator: \.isNewline)
            .map { line in
                try decoder.decode(BookkeepingTransactionOp.self, from: Data(line.utf8))
            }
    }

    private static func opSort(_ lhs: BookkeepingTransactionOp, _ rhs: BookkeepingTransactionOp) -> Bool {
        if lhs.createdAt != rhs.createdAt {
            return lhs.createdAt < rhs.createdAt
        }

        if lhs.deviceId != rhs.deviceId {
            return lhs.deviceId < rhs.deviceId
        }

        return lhs.seq < rhs.seq
    }

    private static let seqFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.minimumIntegerDigits = 10
        formatter.usesGroupingSeparator = false
        return formatter
    }()

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
