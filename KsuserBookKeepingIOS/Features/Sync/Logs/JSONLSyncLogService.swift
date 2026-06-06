import Foundation

protocol SyncLogOperation: Codable {
    var opId: String { get }
    var deviceId: String { get }
    var seq: Int { get }
    var createdAt: Date { get }
    var fileIndex: Int { get }
}

struct SyncLogDescriptor {
    var domain: LedgerSyncDomain
    var remoteDirectory: String
    var opsPerFile: Int

    init(domain: LedgerSyncDomain, remoteDirectory: String, opsPerFile: Int = 100) {
        self.domain = domain
        self.remoteDirectory = remoteDirectory
        self.opsPerFile = opsPerFile
    }

    func deviceDirectory(for deviceId: String) -> String {
        "\(remoteDirectory)/\(deviceId)"
    }
}

struct JSONLSyncLogService<Operation: SyncLogOperation> {
    private let storageProvider: (SyncConfiguration, SyncSecrets) throws -> any SyncStorage

    init(
        storageProvider: @escaping (SyncConfiguration, SyncSecrets) throws -> any SyncStorage = { configuration, secrets in
            try SyncStorageFactory.storage(for: configuration, webDAVSecret: secrets.webDAVSecret)
        }
    ) {
        self.storageProvider = storageProvider
    }

    func backup(
        ops: [Operation],
        configuration: SyncConfiguration,
        secrets: SyncSecrets,
        descriptor: SyncLogDescriptor
    ) async throws {
        guard !ops.isEmpty else { return }

        let storage = try storageProvider(configuration, secrets)
        let groupedOps = Dictionary(grouping: ops) { op in
            opFileName(for: op.seq, opsPerFile: descriptor.opsPerFile)
        }

        for (fileName, fileOps) in groupedOps {
            let sortedOps = fileOps.sorted(by: Self.opSort)
            let deviceId = sortedOps.first?.deviceId ?? DeviceIdentity.currentDeviceId
            let path = "\(descriptor.deviceDirectory(for: deviceId))/\(fileName)"
            let mergedOps = try await mergedOpsForBackup(
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

    func importRemoteOps(
        configuration: SyncConfiguration,
        secrets: SyncSecrets,
        descriptor: SyncLogDescriptor
    ) async throws -> [Operation] {
        let storage = try storageProvider(configuration, secrets)
        let deviceIds: [String]

        do {
            deviceIds = try await storage.listDirectories(at: descriptor.remoteDirectory)
        } catch SyncStorageError.fileNotFound {
            return []
        }

        var importedOps: [Operation] = []
        for deviceId in deviceIds {
            let path = descriptor.deviceDirectory(for: deviceId)
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

    private func opFileName(for seq: Int, opsPerFile: Int) -> String {
        let start = ((seq - 1) / opsPerFile) * opsPerFile + 1
        let end = start + opsPerFile - 1
        let formatter = JSONLSyncLogCoding.seqFormatter
        return "\(formatter.string(from: NSNumber(value: start)) ?? "\(start)")-\(formatter.string(from: NSNumber(value: end)) ?? "\(end)").jsonl"
    }

    private func mergedOpsForBackup(
        localOps: [Operation],
        at path: String,
        storage: any SyncStorage,
        secrets: SyncSecrets
    ) async throws -> [Operation] {
        do {
            let remoteData = try await storage.readFile(at: path)
            let data = try SyncFileEncryption.decryptIfNeeded(remoteData, password: secrets.encryptionPassword)
            let remoteOps = try Self.decodeJSONL(data)
            var opsById = Dictionary(uniqueKeysWithValues: remoteOps.map { ($0.opId, $0) })
            for op in localOps {
                opsById[op.opId] = op
            }
            return opsById.values.sorted(by: Self.opSort)
        } catch SyncStorageError.fileNotFound {
            return localOps
        }
    }

    static func encodeJSONL(_ ops: [Operation]) throws -> Data {
        let lines = try ops.map { op in
            String(data: try JSONLSyncLogCoding.encoder.encode(op), encoding: .utf8) ?? "{}"
        }

        return Data((lines.joined(separator: "\n") + "\n").utf8)
    }

    static func decodeJSONL(_ data: Data) throws -> [Operation] {
        guard let text = String(data: data, encoding: .utf8) else { return [] }

        return try text
            .split(whereSeparator: \.isNewline)
            .map { line in
                try JSONLSyncLogCoding.decoder.decode(Operation.self, from: Data(line.utf8))
            }
    }

    static func opSort(_ lhs: Operation, _ rhs: Operation) -> Bool {
        if lhs.createdAt != rhs.createdAt {
            return lhs.createdAt < rhs.createdAt
        }

        if lhs.deviceId != rhs.deviceId {
            return lhs.deviceId < rhs.deviceId
        }

        return lhs.seq < rhs.seq
    }
}

private enum JSONLSyncLogCoding {
    static let seqFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.minimumIntegerDigits = 10
        formatter.usesGroupingSeparator = false
        return formatter
    }()

    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }()

    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
