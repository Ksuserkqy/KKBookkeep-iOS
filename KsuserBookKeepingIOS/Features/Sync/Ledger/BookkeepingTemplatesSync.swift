import Foundation

enum BookkeepingTemplateOpAction: String, Codable {
    case create
    case update
    case delete
}

struct BookkeepingTemplateOp: SyncLogOperation, Equatable, Identifiable {
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
    private let logService = JSONLSyncLogService<BookkeepingTemplateOp>()

    func backup(ops: [BookkeepingTemplateOp], configuration: SyncConfiguration, secrets: SyncSecrets) async throws {
        try await logService.backup(
            ops: ops,
            configuration: configuration,
            secrets: secrets,
            descriptor: descriptor
        )
    }

    func importRemoteOps(configuration: SyncConfiguration, secrets: SyncSecrets) async throws -> [BookkeepingTemplateOp] {
        try await logService.importRemoteOps(
            configuration: configuration,
            secrets: secrets,
            descriptor: descriptor
        )
    }

    private var descriptor: SyncLogDescriptor {
        SyncLogDescriptor(
            domain: .templates,
            remoteDirectory: "\(ledgerPath)/template-devices",
            opsPerFile: Self.opsPerFile
        )
    }
}
