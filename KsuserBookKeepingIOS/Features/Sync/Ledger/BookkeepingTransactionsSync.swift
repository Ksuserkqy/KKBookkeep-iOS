import Foundation

enum BookkeepingTransactionOpAction: String, Codable {
    case create
    case update
    case delete
}

struct BookkeepingTransactionOp: SyncLogOperation, Equatable, Identifiable {
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

struct BookkeepingTransactionsSyncService {
    static let opsPerFile = 100

    private let ledgerPath = "KKBookKeep/v1/ledgers/default"
    private let logService = JSONLSyncLogService<BookkeepingTransactionOp>()

    func backup(ops: [BookkeepingTransactionOp], configuration: SyncConfiguration, secrets: SyncSecrets) async throws {
        try await logService.backup(
            ops: ops,
            configuration: configuration,
            secrets: secrets,
            descriptor: descriptor
        )
    }

    func importRemoteOps(configuration: SyncConfiguration, secrets: SyncSecrets) async throws -> [BookkeepingTransactionOp] {
        try await logService.importRemoteOps(
            configuration: configuration,
            secrets: secrets,
            descriptor: descriptor
        )
    }

    private var descriptor: SyncLogDescriptor {
        SyncLogDescriptor(
            domain: .transactions,
            remoteDirectory: "\(ledgerPath)/devices",
            opsPerFile: Self.opsPerFile
        )
    }
}
