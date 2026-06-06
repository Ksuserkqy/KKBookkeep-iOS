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

    func testJSONLSyncLogBackupMergesRemoteOpsInSequenceFile() async throws {
        let storage = InMemorySyncStorage()
        let service = JSONLSyncLogService<BookkeepingTransactionOp> { _, _ in storage }
        let descriptor = SyncLogDescriptor(
            domain: .transactions,
            remoteDirectory: "KKBookKeep/v1/ledgers/default/devices"
        )
        let configuration = syncConfiguration(encryptionEnabled: false)
        let remoteOp = transactionOp(opId: "op.remote", seq: 2)
        let localOp = transactionOp(opId: "op.local", seq: 1)
        try await storage.writeFileAtomic(
            JSONLSyncLogService<BookkeepingTransactionOp>.encodeJSONL([remoteOp]),
            to: "KKBookKeep/v1/ledgers/default/devices/device-a/0000000001-0000000100.jsonl"
        )

        try await service.backup(
            ops: [localOp],
            configuration: configuration,
            secrets: SyncSecrets(webDAVSecret: "", encryptionPassword: ""),
            descriptor: descriptor
        )

        let data = try await storage.readFile(at: "KKBookKeep/v1/ledgers/default/devices/device-a/0000000001-0000000100.jsonl")
        let ops = try JSONLSyncLogService<BookkeepingTransactionOp>.decodeJSONL(data)
        XCTAssertEqual(ops.map(\.opId), ["op.local", "op.remote"])
    }

    func testJSONLSyncLogImportReturnsEmptyWhenDirectoryIsMissing() async throws {
        let storage = InMemorySyncStorage()
        let service = JSONLSyncLogService<BookkeepingTransactionOp> { _, _ in storage }
        let ops = try await service.importRemoteOps(
            configuration: syncConfiguration(encryptionEnabled: false),
            secrets: SyncSecrets(webDAVSecret: "", encryptionPassword: ""),
            descriptor: SyncLogDescriptor(domain: .transactions, remoteDirectory: "missing")
        )

        XCTAssertTrue(ops.isEmpty)
    }

    func testJSONLSyncLogSupportsEncryptedFiles() async throws {
        let storage = InMemorySyncStorage()
        let service = JSONLSyncLogService<BookkeepingTransactionOp> { _, _ in storage }
        let descriptor = SyncLogDescriptor(
            domain: .transactions,
            remoteDirectory: "KKBookKeep/v1/ledgers/default/devices"
        )
        let configuration = syncConfiguration(encryptionEnabled: true)
        let secrets = SyncSecrets(webDAVSecret: "", encryptionPassword: "sync-password")

        try await service.backup(
            ops: [transactionOp(opId: "op.encrypted", seq: 1)],
            configuration: configuration,
            secrets: secrets,
            descriptor: descriptor
        )

        let ops = try await service.importRemoteOps(
            configuration: configuration,
            secrets: secrets,
            descriptor: descriptor
        )
        XCTAssertEqual(ops.map(\.opId), ["op.encrypted"])
    }

    func testProfileJSONLSyncLogImportsFieldOpsInStableOrder() async throws {
        let storage = InMemorySyncStorage()
        let service = JSONLSyncLogService<PersonalProfileOp> { _, _ in storage }
        let descriptor = SyncLogDescriptor(domain: .profile, remoteDirectory: "KKBookKeep/v1/profile-devices")
        let configuration = syncConfiguration(encryptionEnabled: false)
        let displayNameOp = profileOp(
            opId: "profile.displayName",
            deviceId: "device-b",
            seq: 1,
            field: .displayName,
            value: "Lamb",
            timestamp: 20
        )
        let emailOp = profileOp(
            opId: "profile.email",
            deviceId: "device-a",
            seq: 1,
            field: .email,
            value: "me@example.com",
            timestamp: 10
        )

        try await service.backup(
            ops: [displayNameOp, emailOp],
            configuration: configuration,
            secrets: SyncSecrets(webDAVSecret: "", encryptionPassword: ""),
            descriptor: descriptor
        )

        let importedOps = try await service.importRemoteOps(
            configuration: configuration,
            secrets: SyncSecrets(webDAVSecret: "", encryptionPassword: ""),
            descriptor: descriptor
        )
        XCTAssertEqual(importedOps.map(\.opId), ["profile.email", "profile.displayName"])
    }

    func testProfileOpSortKeyUsesLaterNicknameUpdate() {
        let earlier = profileOp(
            opId: "nickname.earlier",
            deviceId: "device-a",
            seq: 1,
            field: .displayName,
            value: "A",
            timestamp: 10
        )
        let later = profileOp(
            opId: "nickname.later",
            deviceId: "device-b",
            seq: 1,
            field: .displayName,
            value: "B",
            timestamp: 20
        )

        XCTAssertGreaterThan(later.sortKey, earlier.sortKey)
    }

    private func makeStore() -> LedgerSQLiteStore {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let url = directory.appendingPathComponent("bookkeeping.sqlite")
        return LedgerSQLiteStore(databaseURL: url)
    }

    private func syncConfiguration(encryptionEnabled: Bool) -> SyncConfiguration {
        SyncConfiguration(
            backupEnabled: true,
            provider: .webDAV,
            webDAVAuthentication: .password,
            webDAVServerURL: "https://example.com",
            webDAVUsername: "user",
            backupOnChange: true,
            autoImport: true,
            backupInterval: .tenMinutes,
            encryptionEnabled: encryptionEnabled,
            lastBackupAt: nil
        )
    }

    private func transactionOp(opId: String, seq: Int) -> BookkeepingTransactionOp {
        let transaction = DraftTransaction(
            id: "transaction.\(opId)",
            kind: .expense,
            amountText: "12",
            transferInAmountText: nil,
            categoryId: "category.food",
            accountId: "account.test",
            fromAccountId: nil,
            toAccountId: nil,
            date: Date(timeIntervalSince1970: TimeInterval(seq)),
            note: "",
            location: nil,
            createdAt: Date(timeIntervalSince1970: TimeInterval(seq))
        )
        return BookkeepingTransactionOp(
            opId: opId,
            deviceId: "device-a",
            seq: seq,
            entityId: transaction.id,
            action: .create,
            occurredAt: transaction.createdAt,
            createdAt: transaction.createdAt,
            payload: transaction
        )
    }

    private func profileOp(
        opId: String,
        deviceId: String,
        seq: Int,
        field: PersonalProfileField,
        value: String?,
        timestamp: TimeInterval
    ) -> PersonalProfileOp {
        PersonalProfileOp(
            opId: opId,
            deviceId: deviceId,
            seq: seq,
            field: field,
            occurredAt: Date(timeIntervalSince1970: timestamp),
            createdAt: Date(timeIntervalSince1970: timestamp),
            payload: PersonalProfileFieldValue(stringValue: value)
        )
    }
}

private final class InMemorySyncStorage: SyncStorage {
    private var files: [String: Data] = [:]

    func listFiles(at path: String) async throws -> [String] {
        let prefix = normalizedDirectory(path)
        let names = files.keys.compactMap { filePath -> String? in
            guard filePath.hasPrefix(prefix) else { return nil }
            let relativePath = String(filePath.dropFirst(prefix.count))
            guard !relativePath.isEmpty, !relativePath.contains("/") else { return nil }
            return relativePath
        }
        guard !names.isEmpty else { throw SyncStorageError.fileNotFound }
        return names.sorted()
    }

    func listDirectories(at path: String) async throws -> [String] {
        let prefix = normalizedDirectory(path)
        let names = Set(files.keys.compactMap { filePath -> String? in
            guard filePath.hasPrefix(prefix) else { return nil }
            let relativePath = String(filePath.dropFirst(prefix.count))
            return relativePath.split(separator: "/").first.map(String.init)
        })
        guard !names.isEmpty else { throw SyncStorageError.fileNotFound }
        return names.sorted()
    }

    func readFile(at path: String) async throws -> Data {
        guard let data = files[normalizedFile(path)] else {
            throw SyncStorageError.fileNotFound
        }
        return data
    }

    func writeFileAtomic(_ data: Data, to path: String) async throws {
        files[normalizedFile(path)] = data
    }

    func moveFile(from sourcePath: String, to destinationPath: String) async throws {
        let source = normalizedFile(sourcePath)
        guard let data = files.removeValue(forKey: source) else {
            throw SyncStorageError.fileNotFound
        }
        files[normalizedFile(destinationPath)] = data
    }

    func deleteFile(at path: String) async throws {
        files.removeValue(forKey: normalizedFile(path))
    }

    private func normalizedDirectory(_ path: String) -> String {
        let file = normalizedFile(path)
        return file.isEmpty ? "" : "\(file)/"
    }

    private func normalizedFile(_ path: String) -> String {
        path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }
}
