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

struct BookkeepingMetadataOp: SyncLogOperation, Equatable, Identifiable {
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
    private let logService = JSONLSyncLogService<BookkeepingMetadataOp>()

    func backup(ops: [BookkeepingMetadataOp], configuration: SyncConfiguration, secrets: SyncSecrets) async throws {
        try await logService.backup(
            ops: ops,
            configuration: configuration,
            secrets: secrets,
            descriptor: descriptor
        )
    }

    func importRemoteOps(configuration: SyncConfiguration, secrets: SyncSecrets) async throws -> [BookkeepingMetadataOp] {
        try await logService.importRemoteOps(
            configuration: configuration,
            secrets: secrets,
            descriptor: descriptor
        )
    }

    private var descriptor: SyncLogDescriptor {
        SyncLogDescriptor(
            domain: .metadata,
            remoteDirectory: "\(ledgerPath)/metadata-devices",
            opsPerFile: Self.opsPerFile
        )
    }
}
