import XCTest
@testable import KsuserBookKeepingIOS

final class LedgerSQLiteStoreTests: XCTestCase {
    func testSavesSnapshotToNormalizedTablesIdempotently() {
        let store = makeStore()
        let account = DraftAccount(
            id: "account.test",
            name: "Test Wallet",
            isDefault: true,
            balanceText: "125.50"
        )
        let category = DraftCategory(
            id: "category.food",
            name: "Food",
            isDefault: true,
            kind: .expense,
            iconName: "utensils",
            colorHex: "#F6C343"
        )
        let transaction = DraftTransaction(
            id: "transaction.1",
            kind: .expense,
            amountText: "25.50",
            transferInAmountText: nil,
            categoryId: category.id,
            accountId: account.id,
            fromAccountId: nil,
            toAccountId: nil,
            date: Date(timeIntervalSince1970: 100),
            note: "Lunch",
            location: nil,
            createdAt: Date(timeIntervalSince1970: 90)
        )
        let op = BookkeepingTransactionOp(
            opId: "op.transaction.1",
            deviceId: "device-a",
            seq: 1,
            entityId: transaction.id,
            action: .create,
            occurredAt: transaction.createdAt,
            createdAt: transaction.createdAt,
            payload: transaction
        )
        var snapshot = LedgerSnapshot()
        snapshot.accounts = [account]
        snapshot.categories = [category]
        snapshot.transactions = [transaction]
        snapshot.accountBaseBalanceTextById = [account.id: "100.00"]
        snapshot.localTransactionOps = [op]
        snapshot.processedTransactionOpIds = [op.opId]
        snapshot.importedTransactionSeqByDeviceId = [op.deviceId: op.seq]
        snapshot.transactionOpSortKeysById = [transaction.id: op.sortKey]
        snapshot.nextTransactionOpSeq = 2

        store.saveLedgerSnapshot(snapshot)
        store.saveLedgerSnapshot(snapshot)

        XCTAssertEqual(store.debugUserVersion(), 2)
        XCTAssertEqual(store.debugRowCount(in: "accounts"), 1)
        XCTAssertEqual(store.debugRowCount(in: "categories"), 1)
        XCTAssertEqual(store.debugRowCount(in: "transactions"), 1)
        XCTAssertEqual(store.debugRowCount(in: "sync_ops"), 1)
        XCTAssertEqual(store.debugRowCount(in: "processed_ops"), 1)

        let loaded = store.loadLedgerSnapshot()
        XCTAssertEqual(loaded?.accounts.first?.id, account.id)
        XCTAssertEqual(loaded?.accountBaseBalanceTextById[account.id], "100.00")
        XCTAssertEqual(loaded?.transactions.first?.id, transaction.id)
        XCTAssertEqual(loaded?.nextTransactionOpSeq, 2)
    }

    func testPendingOpsAndUploadedStateComeFromSyncOps() {
        let store = makeStore()
        let template = DraftTransactionTemplate(
            id: "template.1",
            name: "Coffee",
            kind: .expense,
            amountText: "18",
            categoryId: "category.food",
            accountId: "account.test",
            note: "",
            createdAt: Date(timeIntervalSince1970: 10),
            updatedAt: Date(timeIntervalSince1970: 20)
        )
        let op = BookkeepingTemplateOp(
            opId: "op.template.1",
            deviceId: "device-a",
            seq: 1,
            entityId: template.id,
            action: .create,
            occurredAt: template.createdAt,
            createdAt: template.createdAt,
            payload: template
        )
        var snapshot = LedgerSnapshot()
        snapshot.localTemplateOps = [op]
        snapshot.processedTemplateOpIds = [op.opId]
        snapshot.nextTemplateOpSeq = 2

        store.saveLedgerSnapshot(snapshot)
        XCTAssertEqual(store.pendingTemplateOps(forceFullUpload: false).map(\.opId), [op.opId])

        store.markOpsUploaded(domain: .templates, opIds: [op.opId], at: Date(timeIntervalSince1970: 30))

        XCTAssertTrue(store.pendingTemplateOps(forceFullUpload: false).isEmpty)
        XCTAssertEqual(store.pendingTemplateOps(forceFullUpload: true).map(\.opId), [op.opId])
        XCTAssertEqual(store.debugUploadedOpIds(domain: .templates), [op.opId])
    }

    func testProcessedSkippedRemoteOpIsRecorded() {
        let store = makeStore()
        store.saveLedgerSnapshot(LedgerSnapshot())
        let budget = DraftBudget(
            id: "budget.1",
            name: "Monthly",
            scope: .overall,
            targetId: nil,
            amountText: "1000",
            isEnabled: true,
            createdAt: Date(timeIntervalSince1970: 1),
            updatedAt: Date(timeIntervalSince1970: 2)
        )
        let op = BookkeepingBudgetOp(
            opId: "op.remote.budget",
            deviceId: "remote-device",
            seq: 4,
            entityId: budget.id,
            action: .update,
            occurredAt: budget.updatedAt,
            createdAt: budget.updatedAt,
            payload: budget
        )

        store.recordRemoteBudgetOp(op)
        store.recordProcessedOp(
            domain: .budgets,
            opId: op.opId,
            deviceId: op.deviceId,
            seq: op.seq,
            applied: false,
            skippedReason: "stale"
        )

        XCTAssertEqual(store.debugRowCount(in: "sync_ops"), 1)
        XCTAssertEqual(store.debugProcessedOpIds(domain: .budgets), [op.opId])
    }

    func testDeletedTemplatesAndBudgetsAreFilteredFromSnapshot() {
        let store = makeStore()
        let templateKey = TemplateOpSortKey(
            occurredAt: Date(timeIntervalSince1970: 100),
            deviceId: "device-a",
            seq: 2
        )
        let budgetKey = BudgetOpSortKey(
            occurredAt: Date(timeIntervalSince1970: 100),
            deviceId: "device-a",
            seq: 2
        )
        var snapshot = LedgerSnapshot()
        snapshot.deletedTemplateOpSortKeysById = ["template.deleted": templateKey]
        snapshot.deletedBudgetOpSortKeysById = ["budget.deleted": budgetKey]

        store.saveLedgerSnapshot(snapshot)
        let loaded = store.loadLedgerSnapshot()

        XCTAssertEqual(loaded?.transactionTemplates.count, 0)
        XCTAssertEqual(loaded?.budgets.count, 0)
        XCTAssertEqual(loaded?.deletedTemplateOpSortKeysById["template.deleted"]?.seq, templateKey.seq)
        XCTAssertEqual(loaded?.deletedBudgetOpSortKeysById["budget.deleted"]?.seq, budgetKey.seq)
    }

    private func makeStore() -> LedgerSQLiteStore {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let url = directory.appendingPathComponent("bookkeeping.sqlite")
        return LedgerSQLiteStore(databaseURL: url)
    }
}
