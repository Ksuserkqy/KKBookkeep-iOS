import Foundation

enum BookkeepingMetadataOpAction: String, Codable {
    case create
    case update
    case archive
    case upsert
    case delete
}

enum BookkeepingMetadataEntity: String, Codable {
    case account
    case category
}

struct BookkeepingMetadataOpPayload: Codable, Equatable {
    var account: DraftAccount?
    var category: DraftCategory?
}

struct BookkeepingMetadataOp: Codable, Equatable, Identifiable {
    let schemaVersion: Int
    var opId: String
    var ledgerId: String
    var deviceId: String
    var seq: Int
    var entity: BookkeepingMetadataEntity
    var entityId: String
    var action: BookkeepingMetadataOpAction
    var occurredAt: Date
    var createdAt: Date
    var payload: BookkeepingMetadataOpPayload?

    var id: String { opId }

    init(
        opId: String = UUID().uuidString,
        ledgerId: String = "default",
        deviceId: String,
        seq: Int,
        entity: BookkeepingMetadataEntity,
        entityId: String,
        action: BookkeepingMetadataOpAction,
        occurredAt: Date = Date(),
        createdAt: Date = Date(),
        payload: BookkeepingMetadataOpPayload?
    ) {
        self.schemaVersion = 1
        self.opId = opId
        self.ledgerId = ledgerId
        self.deviceId = deviceId
        self.seq = seq
        self.entity = entity
        self.entityId = entityId
        self.action = action
        self.occurredAt = occurredAt
        self.createdAt = createdAt
        self.payload = payload
    }

    var fileIndex: Int {
        max(0, (seq - 1) / BookkeepingMetadataSyncService.opsPerFile)
    }

    var sortKey: MetadataOpSortKey {
        MetadataOpSortKey(occurredAt: occurredAt, deviceId: deviceId, seq: seq)
    }
}

struct MetadataOpSortKey: Codable, Equatable, Comparable {
    var occurredAt: Date
    var deviceId: String
    var seq: Int

    static let zero = MetadataOpSortKey(
        occurredAt: Date(timeIntervalSince1970: 0),
        deviceId: "",
        seq: 0
    )

    static func < (lhs: MetadataOpSortKey, rhs: MetadataOpSortKey) -> Bool {
        if lhs.occurredAt != rhs.occurredAt {
            return lhs.occurredAt < rhs.occurredAt
        }

        if lhs.deviceId != rhs.deviceId {
            return lhs.deviceId < rhs.deviceId
        }

        return lhs.seq < rhs.seq
    }
}

struct BookkeepingMetadataSyncService {
    static let opsPerFile = 100

    private let ledgerPath = "KKBookKeep/v1/ledgers/default"

    func backup(ops: [BookkeepingMetadataOp], configuration: SyncConfiguration, secrets: SyncSecrets) async throws {
        guard !ops.isEmpty else { return }

        let storage = try SyncStorageFactory.storage(for: configuration, webDAVSecret: secrets.webDAVSecret)
        let groupedOps = Dictionary(grouping: ops) { op in
            opFileName(for: op.seq)
        }

        for (fileName, fileOps) in groupedOps {
            let sortedOps = fileOps.sorted(by: Self.opSort)
            let deviceId = sortedOps.first?.deviceId ?? DeviceIdentity.currentDeviceId
            let path = "\(devicePath(for: deviceId))/\(fileName)"
            let mergedOps = try await Self.mergedOpsForBackup(
                localOps: sortedOps,
                at: path,
                storage: storage,
                secrets: secrets
            )
            var data = try Self.encodeJSONL(mergedOps)

            if configuration.encryptionEnabled {
                data = try SyncFileEncryption.encrypt(data, password: secrets.encryptionPassword)
            }

            try await storage.writeFileAtomic(data, to: path)
        }
    }

    func importRemoteOps(configuration: SyncConfiguration, secrets: SyncSecrets) async throws -> [BookkeepingMetadataOp] {
        let storage = try SyncStorageFactory.storage(for: configuration, webDAVSecret: secrets.webDAVSecret)
        let devicesPath = "\(ledgerPath)/metadata-devices"
        let deviceIds: [String]

        do {
            deviceIds = try await storage.listDirectories(at: devicesPath)
        } catch SyncStorageError.fileNotFound {
            return []
        }

        var importedOps: [BookkeepingMetadataOp] = []
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

    private func devicePath(for deviceId: String) -> String {
        "\(ledgerPath)/metadata-devices/\(deviceId)"
    }

    private func opFileName(for seq: Int) -> String {
        let start = ((seq - 1) / Self.opsPerFile) * Self.opsPerFile + 1
        let end = start + Self.opsPerFile - 1
        return "\(Self.seqFormatter.string(from: NSNumber(value: start)) ?? "\(start)")-\(Self.seqFormatter.string(from: NSNumber(value: end)) ?? "\(end)").jsonl"
    }

    private static func encodeJSONL(_ ops: [BookkeepingMetadataOp]) throws -> Data {
        let lines = try ops.map { op in
            String(data: try encoder.encode(op), encoding: .utf8) ?? "{}"
        }

        return Data((lines.joined(separator: "\n") + "\n").utf8)
    }

    private static func decodeJSONL(_ data: Data) throws -> [BookkeepingMetadataOp] {
        guard let text = String(data: data, encoding: .utf8) else { return [] }

        return try text
            .split(whereSeparator: \.isNewline)
            .map { line in
                try decoder.decode(BookkeepingMetadataOp.self, from: Data(line.utf8))
            }
    }

    private static func mergedOpsForBackup(
        localOps: [BookkeepingMetadataOp],
        at path: String,
        storage: any SyncStorage,
        secrets: SyncSecrets
    ) async throws -> [BookkeepingMetadataOp] {
        do {
            let remoteData = try await storage.readFile(at: path)
            let data = try SyncFileEncryption.decryptIfNeeded(remoteData, password: secrets.encryptionPassword)
            let remoteOps = try decodeJSONL(data)
            var opsById = Dictionary(uniqueKeysWithValues: remoteOps.map { ($0.opId, $0) })
            for op in localOps {
                opsById[op.opId] = op
            }
            return opsById.values.sorted(by: opSort)
        } catch SyncStorageError.fileNotFound {
            return localOps
        }
    }

    private static func opSort(_ lhs: BookkeepingMetadataOp, _ rhs: BookkeepingMetadataOp) -> Bool {
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
