import Foundation

enum LedgerReplayAction {
    case upsert
    case delete
}

protocol LedgerReplayOperation: SyncLogOperation {
    associatedtype SortKey: Comparable

    static var zeroReplaySortKey: SortKey { get }

    var replayEntityId: String { get }
    var replaySortKey: SortKey { get }
    var replayAction: LedgerReplayAction { get }
}

enum LedgerOpReplayer {
    static func replaySort<Operation: SyncLogOperation>(_ lhs: Operation, _ rhs: Operation) -> Bool {
        if lhs.createdAt != rhs.createdAt {
            return lhs.createdAt < rhs.createdAt
        }

        if lhs.deviceId != rhs.deviceId {
            return lhs.deviceId < rhs.deviceId
        }

        return lhs.seq < rhs.seq
    }

    static func shouldApply<Operation: LedgerReplayOperation>(
        _ op: Operation,
        currentSortKeysById: [String: Operation.SortKey],
        deletedSortKeysById: [String: Operation.SortKey]
    ) -> Bool {
        let incomingKey = op.replaySortKey
        let currentKey = currentSortKeysById[op.replayEntityId] ?? Operation.zeroReplaySortKey
        let deletedKey = deletedSortKeysById[op.replayEntityId] ?? Operation.zeroReplaySortKey

        switch op.replayAction {
        case .upsert:
            guard incomingKey >= currentKey else { return false }
            guard incomingKey > deletedKey else { return false }
            return true
        case .delete:
            return incomingKey >= currentKey && incomingKey >= deletedKey
        }
    }

    static func applyState<Operation: LedgerReplayOperation>(
        _ op: Operation,
        currentSortKeysById: inout [String: Operation.SortKey],
        deletedSortKeysById: inout [String: Operation.SortKey]
    ) {
        switch op.replayAction {
        case .upsert:
            currentSortKeysById[op.replayEntityId] = op.replaySortKey
            deletedSortKeysById.removeValue(forKey: op.replayEntityId)
        case .delete:
            deletedSortKeysById[op.replayEntityId] = op.replaySortKey
        }
    }
}

extension BookkeepingMetadataOp: LedgerReplayOperation {
    static var zeroReplaySortKey: MetadataOpSortKey { .zero }

    var replayEntityId: String {
        Self.replayEntityKey(entity: entity, id: entityId)
    }

    var replaySortKey: MetadataOpSortKey { sortKey }

    var replayAction: LedgerReplayAction {
        action == .delete ? .delete : .upsert
    }

    static func replayEntityKey(entity: BookkeepingMetadataEntity, id: String) -> String {
        "\(entity.rawValue):\(id)"
    }
}

extension BookkeepingTransactionOp: LedgerReplayOperation {
    static var zeroReplaySortKey: TransactionOpSortKey { .zero }
    var replayEntityId: String { entityId }
    var replaySortKey: TransactionOpSortKey { sortKey }
    var replayAction: LedgerReplayAction { action == .delete ? .delete : .upsert }
}

extension BookkeepingTemplateOp: LedgerReplayOperation {
    static var zeroReplaySortKey: TemplateOpSortKey { .zero }
    var replayEntityId: String { entityId }
    var replaySortKey: TemplateOpSortKey { sortKey }
    var replayAction: LedgerReplayAction { action == .delete ? .delete : .upsert }
}

extension BookkeepingBudgetOp: LedgerReplayOperation {
    static var zeroReplaySortKey: BudgetOpSortKey { .zero }
    var replayEntityId: String { entityId }
    var replaySortKey: BudgetOpSortKey { sortKey }
    var replayAction: LedgerReplayAction { action == .delete ? .delete : .upsert }
}
