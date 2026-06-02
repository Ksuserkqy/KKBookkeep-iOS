import Foundation

enum BookkeepingTemplateOpAction: String, Codable {
    case create
    case update
    case delete
}

struct BookkeepingTemplateOp: Codable, Equatable, Identifiable {
    let schemaVersion: Int
    var opId: String
    var ledgerId: String
    var deviceId: String
    var seq: Int
    var entity: String
    var entityId: String
    var action: BookkeepingTemplateOpAction
    var occurredAt: Date
    var createdAt: Date
    var payload: DraftTransactionTemplate?

    var id: String { opId }

    init(
        opId: String = UUID().uuidString,
        ledgerId: String = "default",
        deviceId: String,
        seq: Int,
        entityId: String,
        action: BookkeepingTemplateOpAction,
        occurredAt: Date,
        createdAt: Date = Date(),
        payload: DraftTransactionTemplate?
    ) {
        self.schemaVersion = 1
        self.opId = opId
        self.ledgerId = ledgerId
        self.deviceId = deviceId
        self.seq = seq
        self.entity = "transactionTemplate"
        self.entityId = entityId
        self.action = action
        self.occurredAt = occurredAt
        self.createdAt = createdAt
        self.payload = payload
    }

    var fileIndex: Int {
        max(0, (seq - 1) / BookkeepingTemplatesSyncService.opsPerFile)
    }

    var sortKey: TemplateOpSortKey {
        TemplateOpSortKey(occurredAt: occurredAt, deviceId: deviceId, seq: seq)
    }
}

struct TemplateOpSortKey: Codable, Equatable, Comparable {
    var occurredAt: Date
    var deviceId: String
    var seq: Int

    static let zero = TemplateOpSortKey(
        occurredAt: Date(timeIntervalSince1970: 0),
        deviceId: "",
        seq: 0
    )

    static func < (lhs: TemplateOpSortKey, rhs: TemplateOpSortKey) -> Bool {
        if lhs.occurredAt != rhs.occurredAt {
            return lhs.occurredAt < rhs.occurredAt
        }

        if lhs.deviceId != rhs.deviceId {
            return lhs.deviceId < rhs.deviceId
        }

        return lhs.seq < rhs.seq
    }
}

struct BookkeepingTemplatesSyncService {
    static let opsPerFile = 100

    private let ledgerPath = "KKBookKeep/v1/ledgers/default"

    func backup(ops: [BookkeepingTemplateOp], configuration: SyncConfiguration, secrets: SyncSecrets) async throws {
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

    func importRemoteOps(configuration: SyncConfiguration, secrets: SyncSecrets) async throws -> [BookkeepingTemplateOp] {
        let storage = try SyncStorageFactory.storage(for: configuration, webDAVSecret: secrets.webDAVSecret)
        let devicesPath = "\(ledgerPath)/template-devices"
        let deviceIds: [String]

        do {
            deviceIds = try await storage.listDirectories(at: devicesPath)
        } catch SyncStorageError.fileNotFound {
            return []
        }

        var importedOps: [BookkeepingTemplateOp] = []
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
        "\(ledgerPath)/template-devices/\(deviceId)"
    }

    private func opFileName(for seq: Int) -> String {
        let start = ((seq - 1) / Self.opsPerFile) * Self.opsPerFile + 1
        let end = start + Self.opsPerFile - 1
        return "\(Self.seqFormatter.string(from: NSNumber(value: start)) ?? "\(start)")-\(Self.seqFormatter.string(from: NSNumber(value: end)) ?? "\(end)").jsonl"
    }

    private static func encodeJSONL(_ ops: [BookkeepingTemplateOp]) throws -> Data {
        let lines = try ops.map { op in
            String(data: try encoder.encode(op), encoding: .utf8) ?? "{}"
        }

        return Data((lines.joined(separator: "\n") + "\n").utf8)
    }

    private static func decodeJSONL(_ data: Data) throws -> [BookkeepingTemplateOp] {
        guard let text = String(data: data, encoding: .utf8) else { return [] }

        return try text
            .split(whereSeparator: \.isNewline)
            .map { line in
                try decoder.decode(BookkeepingTemplateOp.self, from: Data(line.utf8))
            }
    }

    private static func opSort(_ lhs: BookkeepingTemplateOp, _ rhs: BookkeepingTemplateOp) -> Bool {
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
