import Foundation

enum BookkeepingBudgetOpAction: String, Codable {
    case create
    case update
    case delete
}

struct BookkeepingBudgetOp: SyncLogOperation, Equatable, Identifiable {
    let schemaVersion: Int
    var opId: String
    var ledgerId: String
    var deviceId: String
    var seq: Int
    var entity: String
    var entityId: String
    var action: BookkeepingBudgetOpAction
    var occurredAt: Date
    var createdAt: Date
    var payload: DraftBudget?

    var id: String { opId }

    init(
        opId: String = UUID().uuidString,
        ledgerId: String = "default",
        deviceId: String,
        seq: Int,
        entityId: String,
        action: BookkeepingBudgetOpAction,
        occurredAt: Date,
        createdAt: Date = Date(),
        payload: DraftBudget?
    ) {
        self.schemaVersion = 1
        self.opId = opId
        self.ledgerId = ledgerId
        self.deviceId = deviceId
        self.seq = seq
        self.entity = "budget"
        self.entityId = entityId
        self.action = action
        self.occurredAt = occurredAt
        self.createdAt = createdAt
        self.payload = payload
    }

    var fileIndex: Int {
        max(0, (seq - 1) / BookkeepingBudgetsSyncService.opsPerFile)
    }

    var sortKey: BudgetOpSortKey {
        BudgetOpSortKey(occurredAt: occurredAt, deviceId: deviceId, seq: seq)
    }
}

struct BudgetOpSortKey: Codable, Equatable, Comparable {
    var occurredAt: Date
    var deviceId: String
    var seq: Int

    static let zero = BudgetOpSortKey(
        occurredAt: Date(timeIntervalSince1970: 0),
        deviceId: "",
        seq: 0
    )

    static func < (lhs: BudgetOpSortKey, rhs: BudgetOpSortKey) -> Bool {
        if lhs.occurredAt != rhs.occurredAt {
            return lhs.occurredAt < rhs.occurredAt
        }

        if lhs.deviceId != rhs.deviceId {
            return lhs.deviceId < rhs.deviceId
        }

        return lhs.seq < rhs.seq
    }
}

struct BookkeepingBudgetsSyncService {
    static let opsPerFile = 100

    private let ledgerPath = "KKBookKeep/v1/ledgers/default"
    private let logService = JSONLSyncLogService<BookkeepingBudgetOp>()

    func backup(ops: [BookkeepingBudgetOp], configuration: SyncConfiguration, secrets: SyncSecrets) async throws {
        try await logService.backup(
            ops: ops,
            configuration: configuration,
            secrets: secrets,
            descriptor: descriptor
        )
    }

    func importRemoteOps(configuration: SyncConfiguration, secrets: SyncSecrets) async throws -> [BookkeepingBudgetOp] {
        try await logService.importRemoteOps(
            configuration: configuration,
            secrets: secrets,
            descriptor: descriptor
        )
    }

    private var descriptor: SyncLogDescriptor {
        SyncLogDescriptor(
            domain: .budgets,
            remoteDirectory: "\(ledgerPath)/budget-devices",
            opsPerFile: Self.opsPerFile
        )
    }
}
