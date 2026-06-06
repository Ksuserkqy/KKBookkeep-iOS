import Foundation
import SQLite3

enum LedgerSyncDomain: String, CaseIterable {
    case profile
    case metadata
    case transactions
    case templates
    case budgets
}

struct LedgerSnapshot {
    var accounts: [DraftAccount] = []
    var categories: [DraftCategory] = []
    var transactions: [DraftTransaction] = []
    var transactionTemplates: [DraftTransactionTemplate] = []
    var budgets: [DraftBudget] = []
    var lastDraft: DraftTransaction?

    var metadataRevision: Int = 0
    var metadataUpdatedAt: Date = Date(timeIntervalSince1970: 0)
    var metadataUpdatedByDeviceId: String = DeviceIdentity.currentDeviceId
    var nextMetadataOpSeq: Int = 1
    var localMetadataOps: [BookkeepingMetadataOp] = []
    var uploadedMetadataOpIds: Set<String> = []
    var processedMetadataOpIds: Set<String> = []
    var importedMetadataSeqByDeviceId: [String: Int] = [:]
    var metadataOpSortKeysById: [String: MetadataOpSortKey] = [:]
    var deletedMetadataOpSortKeysById: [String: MetadataOpSortKey] = [:]

    var transactionsRevision: Int = 0
    var transactionsUpdatedAt: Date = Date(timeIntervalSince1970: 0)
    var transactionsUpdatedByDeviceId: String = DeviceIdentity.currentDeviceId
    var nextTransactionOpSeq: Int = 1
    var localTransactionOps: [BookkeepingTransactionOp] = []
    var uploadedTransactionOpIds: Set<String> = []
    var processedTransactionOpIds: Set<String> = []
    var importedTransactionSeqByDeviceId: [String: Int] = [:]
    var transactionOpSortKeysById: [String: TransactionOpSortKey] = [:]
    var deletedTransactionOpSortKeysById: [String: TransactionOpSortKey] = [:]
    var accountBaseBalanceTextById: [String: String] = [:]

    var nextTemplateOpSeq: Int = 1
    var localTemplateOps: [BookkeepingTemplateOp] = []
    var uploadedTemplateOpIds: Set<String> = []
    var processedTemplateOpIds: Set<String> = []
    var importedTemplateSeqByDeviceId: [String: Int] = [:]
    var templateOpSortKeysById: [String: TemplateOpSortKey] = [:]
    var deletedTemplateOpSortKeysById: [String: TemplateOpSortKey] = [:]

    var nextBudgetOpSeq: Int = 1
    var localBudgetOps: [BookkeepingBudgetOp] = []
    var uploadedBudgetOpIds: Set<String> = []
    var processedBudgetOpIds: Set<String> = []
    var importedBudgetSeqByDeviceId: [String: Int] = [:]
    var budgetOpSortKeysById: [String: BudgetOpSortKey] = [:]
    var deletedBudgetOpSortKeysById: [String: BudgetOpSortKey] = [:]
}

final class LedgerSQLiteStore {
    enum StoreError: Error {
        case openFailed(String)
        case prepareFailed(String)
        case stepFailed(String)
        case bindFailed(String)
    }

    static let shared = LedgerSQLiteStore()

    private let databaseURL: URL
    private var db: OpaquePointer?

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

    private static let isoFormatter = ISO8601DateFormatter()

    init(databaseURL: URL? = nil, fileManager: FileManager = .default) {
        if let databaseURL {
            self.databaseURL = databaseURL
            try? fileManager.createDirectory(at: databaseURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        } else {
            let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? fileManager.temporaryDirectory
            let ledgerDirectory = appSupportURL
                .appendingPathComponent("KKBookkeep", isDirectory: true)
                .appendingPathComponent("Ledger", isDirectory: true)
            try? fileManager.createDirectory(at: ledgerDirectory, withIntermediateDirectories: true)
            self.databaseURL = ledgerDirectory.appendingPathComponent("bookkeeping.sqlite")
        }

        do {
            try open()
            try configure()
            try migrate()
        } catch {
            assertionFailure("Failed to initialize ledger SQLite store: \(error)")
        }
    }

    deinit {
        if let db {
            sqlite3_close(db)
        }
    }

    func saveLedgerSnapshot(_ snapshot: LedgerSnapshot) {
        do {
            try writeLedgerSnapshot(snapshot)
        } catch {
            assertionFailure("Failed to save ledger SQLite snapshot: \(error)")
        }
    }

    func loadLedgerSnapshot() -> LedgerSnapshot? {
        do {
            return try readLedgerSnapshot()
        } catch {
            assertionFailure("Failed to load ledger SQLite snapshot: \(error)")
            return nil
        }
    }

    func resetLedgerData() throws {
        try ensureNormalizedSchema()
        try transaction {
            try execute("DELETE FROM processed_ops")
            try execute("DELETE FROM sync_ops")
            try execute("DELETE FROM entity_sync_state")
            try execute("DELETE FROM sync_cursors")
            try execute("DELETE FROM ledger_metadata")
            try execute("DELETE FROM budgets")
            try execute("DELETE FROM transaction_templates")
            try execute("DELETE FROM transactions")
            try execute("DELETE FROM categories")
            try execute("DELETE FROM accounts")
        }
    }

    func pendingMetadataOps(forceFullUpload: Bool) -> [BookkeepingMetadataOp] {
        (try? readMetadataOps(pendingOnly: !forceFullUpload)) ?? []
    }

    func metadataOps(fileIndexes: Set<Int>) -> [BookkeepingMetadataOp] {
        guard !fileIndexes.isEmpty else { return [] }
        return ((try? readMetadataOps(pendingOnly: false)) ?? []).filter { fileIndexes.contains($0.fileIndex) }
    }

    func pendingTransactionOps(forceFullUpload: Bool) -> [BookkeepingTransactionOp] {
        (try? readTransactionOps(pendingOnly: !forceFullUpload)) ?? []
    }

    func transactionOps(fileIndexes: Set<Int>) -> [BookkeepingTransactionOp] {
        guard !fileIndexes.isEmpty else { return [] }
        return ((try? readTransactionOps(pendingOnly: false)) ?? []).filter { fileIndexes.contains($0.fileIndex) }
    }

    func pendingTemplateOps(forceFullUpload: Bool) -> [BookkeepingTemplateOp] {
        (try? readTemplateOps(pendingOnly: !forceFullUpload)) ?? []
    }

    func templateOps(fileIndexes: Set<Int>) -> [BookkeepingTemplateOp] {
        guard !fileIndexes.isEmpty else { return [] }
        return ((try? readTemplateOps(pendingOnly: false)) ?? []).filter { fileIndexes.contains($0.fileIndex) }
    }

    func pendingBudgetOps(forceFullUpload: Bool) -> [BookkeepingBudgetOp] {
        (try? readBudgetOps(pendingOnly: !forceFullUpload)) ?? []
    }

    func budgetOps(fileIndexes: Set<Int>) -> [BookkeepingBudgetOp] {
        guard !fileIndexes.isEmpty else { return [] }
        return ((try? readBudgetOps(pendingOnly: false)) ?? []).filter { fileIndexes.contains($0.fileIndex) }
    }

    func markOpsUploaded(domain: LedgerSyncDomain, opIds: [String], at date: Date = Date()) {
        guard !opIds.isEmpty else { return }

        do {
            try ensureNormalizedSchema()
            let uploadedAt = Self.isoString(from: date)
            try transaction {
                for opId in opIds {
                    try executePrepared(
                        """
                        UPDATE sync_ops
                        SET uploaded_at = ?
                        WHERE domain = ? AND op_id = ? AND source = 'local'
                        """,
                        bindings: [.text(uploadedAt), .text(domain.rawValue), .text(opId)]
                    )
                }
            }
        } catch {
            assertionFailure("Failed to mark SQLite sync ops uploaded: \(error)")
        }
    }

    func recordRemoteMetadataOp(_ op: BookkeepingMetadataOp) {
        recordRemoteOp(
            opId: op.opId,
            domain: .metadata,
            schemaVersion: op.schemaVersion,
            ledgerId: op.ledgerId,
            deviceId: op.deviceId,
            seq: op.seq,
            entity: op.entity.rawValue,
            entityId: op.entityId,
            action: op.action.rawValue,
            occurredAt: op.occurredAt,
            createdAt: op.createdAt,
            payload: op.payload
        )
    }

    func recordRemoteTransactionOp(_ op: BookkeepingTransactionOp) {
        recordRemoteOp(
            opId: op.opId,
            domain: .transactions,
            schemaVersion: op.schemaVersion,
            ledgerId: op.ledgerId,
            deviceId: op.deviceId,
            seq: op.seq,
            entity: op.entity,
            entityId: op.entityId,
            action: op.action.rawValue,
            occurredAt: op.occurredAt,
            createdAt: op.createdAt,
            payload: op.payload
        )
    }

    func recordRemoteTemplateOp(_ op: BookkeepingTemplateOp) {
        recordRemoteOp(
            opId: op.opId,
            domain: .templates,
            schemaVersion: op.schemaVersion,
            ledgerId: op.ledgerId,
            deviceId: op.deviceId,
            seq: op.seq,
            entity: op.entity,
            entityId: op.entityId,
            action: op.action.rawValue,
            occurredAt: op.occurredAt,
            createdAt: op.createdAt,
            payload: op.payload
        )
    }

    func recordRemoteBudgetOp(_ op: BookkeepingBudgetOp) {
        recordRemoteOp(
            opId: op.opId,
            domain: .budgets,
            schemaVersion: op.schemaVersion,
            ledgerId: op.ledgerId,
            deviceId: op.deviceId,
            seq: op.seq,
            entity: op.entity,
            entityId: op.entityId,
            action: op.action.rawValue,
            occurredAt: op.occurredAt,
            createdAt: op.createdAt,
            payload: op.payload
        )
    }

    func recordProcessedOp(
        domain: LedgerSyncDomain,
        opId: String,
        deviceId: String,
        seq: Int,
        applied: Bool,
        skippedReason: String? = nil,
        processedAt: Date = Date()
    ) {
        do {
            try ensureNormalizedSchema()
            try upsertProcessedOp(
                opId: opId,
                domain: domain,
                deviceId: deviceId,
                seq: seq,
                applied: applied,
                skippedReason: skippedReason,
                processedAt: processedAt
            )
        } catch {
            assertionFailure("Failed to record processed SQLite sync op: \(error)")
        }
    }

    func nextLocalSeq(for domain: LedgerSyncDomain, deviceId: String = DeviceIdentity.currentDeviceId) -> Int {
        do {
            let sql = "SELECT COALESCE(MAX(seq), 0) FROM sync_ops WHERE domain = ? AND device_id = ? AND source = 'local'"
            let statement = try prepare(sql)
            defer { sqlite3_finalize(statement) }

            bindText(domain.rawValue, to: statement, index: 1)
            bindText(deviceId, to: statement, index: 2)
            guard sqlite3_step(statement) == SQLITE_ROW else { return 1 }
            return Int(sqlite3_column_int64(statement, 0)) + 1
        } catch {
            return 1
        }
    }

    #if DEBUG
    func debugUserVersion() -> Int {
        userVersion
    }

    func debugRowCount(in table: String) -> Int {
        guard table.range(of: #"^[A-Za-z_]+$"#, options: .regularExpression) != nil else {
            return 0
        }

        do {
            let statement = try prepare("SELECT COUNT(*) FROM \(table)")
            defer { sqlite3_finalize(statement) }
            guard sqlite3_step(statement) == SQLITE_ROW else { return 0 }
            return Int(sqlite3_column_int64(statement, 0))
        } catch {
            return 0
        }
    }

    func debugProcessedOpIds(domain: LedgerSyncDomain) -> Set<String> {
        (try? readProcessedOpIds(domain: domain)) ?? []
    }

    func debugUploadedOpIds(domain: LedgerSyncDomain) -> Set<String> {
        (try? readUploadedOpIds(domain: domain)) ?? []
    }
    #endif

    private func open() throws {
        guard db == nil else { return }
        if sqlite3_open(databaseURL.path, &db) != SQLITE_OK {
            throw StoreError.openFailed(lastErrorMessage)
        }
    }

    private func configure() throws {
        try execute("PRAGMA journal_mode = WAL")
        try execute("PRAGMA foreign_keys = ON")
    }

    private func migrate() throws {
        try ensureNormalizedSchema()
        try setUserVersion(2)
    }

    private func ensureNormalizedSchema() throws {
        try execute(
            """
            CREATE TABLE IF NOT EXISTS ledger_metadata (
                key TEXT PRIMARY KEY NOT NULL,
                value TEXT NOT NULL,
                updated_at TEXT NOT NULL
            )
            """
        )
        try execute(
            """
            CREATE TABLE IF NOT EXISTS accounts (
                id TEXT PRIMARY KEY NOT NULL,
                name TEXT NOT NULL,
                is_default INTEGER NOT NULL DEFAULT 0,
                type TEXT NOT NULL,
                icon_name TEXT NOT NULL,
                color_hex TEXT NOT NULL,
                base_balance_text TEXT NOT NULL,
                balance_text TEXT NOT NULL,
                note TEXT NOT NULL DEFAULT '',
                archived_at TEXT,
                created_at TEXT,
                updated_at TEXT
            )
            """
        )
        try execute(
            """
            CREATE TABLE IF NOT EXISTS categories (
                id TEXT PRIMARY KEY NOT NULL,
                name TEXT NOT NULL,
                is_default INTEGER NOT NULL DEFAULT 0,
                kind TEXT NOT NULL,
                parent_id TEXT,
                icon_name TEXT NOT NULL,
                color_hex TEXT NOT NULL,
                archived_at TEXT,
                created_at TEXT,
                updated_at TEXT,
                FOREIGN KEY(parent_id) REFERENCES categories(id) ON DELETE SET NULL
            )
            """
        )
        try execute("CREATE INDEX IF NOT EXISTS idx_categories_kind_parent ON categories(kind, parent_id)")
        try execute(
            """
            CREATE TABLE IF NOT EXISTS transactions (
                id TEXT PRIMARY KEY NOT NULL,
                kind TEXT NOT NULL,
                amount_text TEXT NOT NULL,
                transfer_in_amount_text TEXT,
                category_id TEXT,
                account_id TEXT,
                from_account_id TEXT,
                to_account_id TEXT,
                date TEXT NOT NULL,
                note TEXT NOT NULL DEFAULT '',
                location_json TEXT,
                created_at TEXT NOT NULL,
                updated_at TEXT,
                deleted_at TEXT,
                FOREIGN KEY(category_id) REFERENCES categories(id) ON DELETE SET NULL,
                FOREIGN KEY(account_id) REFERENCES accounts(id) ON DELETE SET NULL,
                FOREIGN KEY(from_account_id) REFERENCES accounts(id) ON DELETE SET NULL,
                FOREIGN KEY(to_account_id) REFERENCES accounts(id) ON DELETE SET NULL
            )
            """
        )
        try execute("CREATE INDEX IF NOT EXISTS idx_transactions_date ON transactions(date DESC, created_at DESC)")
        try execute("CREATE INDEX IF NOT EXISTS idx_transactions_account ON transactions(account_id)")
        try execute("CREATE INDEX IF NOT EXISTS idx_transactions_category ON transactions(category_id)")
        try execute("CREATE INDEX IF NOT EXISTS idx_transactions_deleted ON transactions(deleted_at)")
        try execute(
            """
            CREATE TABLE IF NOT EXISTS transaction_templates (
                id TEXT PRIMARY KEY NOT NULL,
                name TEXT NOT NULL,
                kind TEXT NOT NULL,
                amount_text TEXT NOT NULL,
                category_id TEXT NOT NULL,
                account_id TEXT NOT NULL,
                note TEXT NOT NULL DEFAULT '',
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL,
                deleted_at TEXT,
                FOREIGN KEY(category_id) REFERENCES categories(id) ON DELETE RESTRICT,
                FOREIGN KEY(account_id) REFERENCES accounts(id) ON DELETE RESTRICT
            )
            """
        )
        try execute(
            """
            CREATE TABLE IF NOT EXISTS budgets (
                id TEXT PRIMARY KEY NOT NULL,
                name TEXT NOT NULL,
                scope TEXT NOT NULL,
                target_id TEXT,
                amount_text TEXT NOT NULL,
                is_enabled INTEGER NOT NULL DEFAULT 1,
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL,
                deleted_at TEXT
            )
            """
        )
        try execute(
            """
            CREATE TABLE IF NOT EXISTS sync_ops (
                op_id TEXT PRIMARY KEY NOT NULL,
                domain TEXT NOT NULL,
                schema_version INTEGER NOT NULL,
                ledger_id TEXT NOT NULL,
                device_id TEXT NOT NULL,
                seq INTEGER NOT NULL,
                entity TEXT NOT NULL,
                entity_id TEXT NOT NULL,
                action TEXT NOT NULL,
                occurred_at TEXT NOT NULL,
                created_at TEXT NOT NULL,
                payload_json TEXT,
                uploaded_at TEXT,
                source TEXT NOT NULL DEFAULT 'local'
            )
            """
        )
        try ensureSyncOpsDeviceSeqIndex()
        try execute("CREATE INDEX IF NOT EXISTS idx_sync_ops_upload ON sync_ops(domain, uploaded_at, seq)")
        try execute("CREATE INDEX IF NOT EXISTS idx_sync_ops_entity ON sync_ops(domain, entity, entity_id)")
        try execute(
            """
            CREATE TABLE IF NOT EXISTS processed_ops (
                op_id TEXT PRIMARY KEY NOT NULL,
                domain TEXT NOT NULL,
                device_id TEXT NOT NULL,
                seq INTEGER NOT NULL,
                processed_at TEXT NOT NULL,
                applied INTEGER NOT NULL,
                skipped_reason TEXT
            )
            """
        )
        try execute(
            """
            CREATE TABLE IF NOT EXISTS entity_sync_state (
                domain TEXT NOT NULL,
                entity TEXT NOT NULL,
                entity_id TEXT NOT NULL,
                current_occurred_at TEXT,
                current_device_id TEXT,
                current_seq INTEGER,
                deleted_occurred_at TEXT,
                deleted_device_id TEXT,
                deleted_seq INTEGER,
                PRIMARY KEY(domain, entity, entity_id)
            )
            """
        )
        try execute(
            """
            CREATE TABLE IF NOT EXISTS sync_cursors (
                domain TEXT NOT NULL,
                remote_device_id TEXT NOT NULL,
                last_seq INTEGER NOT NULL DEFAULT 0,
                updated_at TEXT NOT NULL,
                PRIMARY KEY(domain, remote_device_id)
            )
            """
        )
    }

    private func writeLedgerSnapshot(_ snapshot: LedgerSnapshot) throws {
        try ensureNormalizedSchema()
        try transaction {
            try upsertAccounts(snapshot.accounts, baseBalanceTextById: snapshot.accountBaseBalanceTextById)
            try upsertCategories(snapshot.categories)
            try upsertTransactions(snapshot.transactions, deletedKeysById: snapshot.deletedTransactionOpSortKeysById)
            try upsertTemplates(snapshot.transactionTemplates, deletedKeysById: snapshot.deletedTemplateOpSortKeysById)
            try upsertBudgets(snapshot.budgets, deletedKeysById: snapshot.deletedBudgetOpSortKeysById)
            try pruneRemovedAccounts(keeping: Set(snapshot.accounts.map(\.id)))
            try pruneRemovedCategories(keeping: Set(snapshot.categories.map(\.id)))
            try replaceLocalSyncOps(snapshot)
            try upsertProcessedOps(snapshot)
            try replaceEntitySyncState(snapshot)
            try replaceSyncCursors(snapshot)
            try persistLedgerMetadata(snapshot)
        }
    }

    private func ensureSyncOpsDeviceSeqIndex() throws {
        let existingSQL = try indexSQL(named: "idx_sync_ops_device_seq_domain")
        if let existingSQL, !existingSQL.localizedCaseInsensitiveContains("source") {
            try execute("DROP INDEX IF EXISTS idx_sync_ops_device_seq_domain")
        }
        try execute("CREATE UNIQUE INDEX IF NOT EXISTS idx_sync_ops_device_seq_domain ON sync_ops(domain, device_id, seq, source)")
    }

    private func indexSQL(named name: String) throws -> String? {
        let statement = try prepare(
            """
            SELECT sql FROM sqlite_master
            WHERE type = 'index' AND name = ?
            LIMIT 1
            """
        )
        defer { sqlite3_finalize(statement) }
        bindText(name, to: statement, index: 1)
        guard sqlite3_step(statement) == SQLITE_ROW else { return nil }
        return columnOptionalText(statement, 0)
    }

    private func readLedgerSnapshot() throws -> LedgerSnapshot {
        try ensureNormalizedSchema()
        var snapshot = LedgerSnapshot()
        snapshot.accounts = try readAccounts()
        snapshot.categories = try readCategories()
        snapshot.transactions = try readTransactions()
        snapshot.transactionTemplates = try readTemplates()
        snapshot.budgets = try readBudgets()
        snapshot.lastDraft = snapshot.transactions.first
        snapshot.accountBaseBalanceTextById = try readAccountBaseBalances()

        snapshot.metadataRevision = readMetadataInt(.metadataRevision) ?? 0
        snapshot.metadataUpdatedAt = readMetadataDate(.metadataUpdatedAt) ?? Date(timeIntervalSince1970: 0)
        snapshot.metadataUpdatedByDeviceId = readMetadataString(.metadataUpdatedByDeviceId) ?? DeviceIdentity.currentDeviceId
        snapshot.transactionsRevision = readMetadataInt(.transactionsRevision) ?? 0
        snapshot.transactionsUpdatedAt = readMetadataDate(.transactionsUpdatedAt) ?? Date(timeIntervalSince1970: 0)
        snapshot.transactionsUpdatedByDeviceId = readMetadataString(.transactionsUpdatedByDeviceId) ?? DeviceIdentity.currentDeviceId

        snapshot.localMetadataOps = try readMetadataOps(pendingOnly: false)
        snapshot.localTransactionOps = try readTransactionOps(pendingOnly: false)
        snapshot.localTemplateOps = try readTemplateOps(pendingOnly: false)
        snapshot.localBudgetOps = try readBudgetOps(pendingOnly: false)

        snapshot.uploadedMetadataOpIds = try readUploadedOpIds(domain: .metadata)
        snapshot.uploadedTransactionOpIds = try readUploadedOpIds(domain: .transactions)
        snapshot.uploadedTemplateOpIds = try readUploadedOpIds(domain: .templates)
        snapshot.uploadedBudgetOpIds = try readUploadedOpIds(domain: .budgets)

        snapshot.processedMetadataOpIds = try readProcessedOpIds(domain: .metadata)
        snapshot.processedTransactionOpIds = try readProcessedOpIds(domain: .transactions)
        snapshot.processedTemplateOpIds = try readProcessedOpIds(domain: .templates)
        snapshot.processedBudgetOpIds = try readProcessedOpIds(domain: .budgets)

        snapshot.importedMetadataSeqByDeviceId = try readSyncCursors(domain: .metadata)
        snapshot.importedTransactionSeqByDeviceId = try readSyncCursors(domain: .transactions)
        snapshot.importedTemplateSeqByDeviceId = try readSyncCursors(domain: .templates)
        snapshot.importedBudgetSeqByDeviceId = try readSyncCursors(domain: .budgets)

        let metadataStates = try readMetadataEntityStates()
        snapshot.metadataOpSortKeysById = metadataStates.current
        snapshot.deletedMetadataOpSortKeysById = metadataStates.deleted

        let transactionStates = try readSimpleEntityStates(domain: .transactions)
        snapshot.transactionOpSortKeysById = transactionStates.current.mapValues {
            TransactionOpSortKey(occurredAt: $0.occurredAt, deviceId: $0.deviceId, seq: $0.seq)
        }
        snapshot.deletedTransactionOpSortKeysById = transactionStates.deleted.mapValues {
            TransactionOpSortKey(occurredAt: $0.occurredAt, deviceId: $0.deviceId, seq: $0.seq)
        }

        let templateStates = try readSimpleEntityStates(domain: .templates)
        snapshot.templateOpSortKeysById = templateStates.current.mapValues {
            TemplateOpSortKey(occurredAt: $0.occurredAt, deviceId: $0.deviceId, seq: $0.seq)
        }
        snapshot.deletedTemplateOpSortKeysById = templateStates.deleted.mapValues {
            TemplateOpSortKey(occurredAt: $0.occurredAt, deviceId: $0.deviceId, seq: $0.seq)
        }

        let budgetStates = try readSimpleEntityStates(domain: .budgets)
        snapshot.budgetOpSortKeysById = budgetStates.current.mapValues {
            BudgetOpSortKey(occurredAt: $0.occurredAt, deviceId: $0.deviceId, seq: $0.seq)
        }
        snapshot.deletedBudgetOpSortKeysById = budgetStates.deleted.mapValues {
            BudgetOpSortKey(occurredAt: $0.occurredAt, deviceId: $0.deviceId, seq: $0.seq)
        }

        snapshot.nextMetadataOpSeq = max(nextLocalSeq(for: .metadata), readMetadataInt(.metadataNextSeq) ?? 1)
        snapshot.nextTransactionOpSeq = max(nextLocalSeq(for: .transactions), readMetadataInt(.transactionNextSeq) ?? 1)
        snapshot.nextTemplateOpSeq = max(nextLocalSeq(for: .templates), readMetadataInt(.templateNextSeq) ?? 1)
        snapshot.nextBudgetOpSeq = max(nextLocalSeq(for: .budgets), readMetadataInt(.budgetNextSeq) ?? 1)

        return snapshot
    }

    private func upsertAccounts(_ accounts: [DraftAccount], baseBalanceTextById: [String: String]) throws {
        for account in accounts {
            try executePrepared(
                """
                INSERT INTO accounts (
                    id, name, is_default, type, icon_name, color_hex,
                    base_balance_text, balance_text, note, archived_at
                )
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(id) DO UPDATE SET
                    name = excluded.name,
                    is_default = excluded.is_default,
                    type = excluded.type,
                    icon_name = excluded.icon_name,
                    color_hex = excluded.color_hex,
                    base_balance_text = excluded.base_balance_text,
                    balance_text = excluded.balance_text,
                    note = excluded.note,
                    archived_at = excluded.archived_at
                """,
                bindings: [
                    .text(account.id),
                    .text(account.name),
                    .int(account.isDefault ? 1 : 0),
                    .text(account.type.rawValue),
                    .text(account.iconName),
                    .text(account.colorHex),
                    .text(baseBalanceTextById[account.id] ?? account.balanceText),
                    .text(account.balanceText),
                    .text(account.note),
                    .nullableText(account.archivedAt.map(Self.isoString))
                ]
            )
        }
    }

    private func upsertCategories(_ categories: [DraftCategory]) throws {
        for category in categories {
            try executePrepared(
                """
                INSERT INTO categories (
                    id, name, is_default, kind, parent_id, icon_name, color_hex, archived_at
                )
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(id) DO UPDATE SET
                    name = excluded.name,
                    is_default = excluded.is_default,
                    kind = excluded.kind,
                    parent_id = NULL,
                    icon_name = excluded.icon_name,
                    color_hex = excluded.color_hex,
                    archived_at = excluded.archived_at
                """,
                bindings: [
                    .text(category.id),
                    .text(category.name),
                    .int(category.isDefault ? 1 : 0),
                    .text(category.kind.rawValue),
                    .nullableText(nil),
                    .text(category.iconName),
                    .text(category.colorHex),
                    .nullableText(category.archivedAt.map(Self.isoString))
                ]
            )
        }

        let ids = Set(categories.map(\.id))
        for category in categories {
            let parentId = category.parentId.flatMap { ids.contains($0) ? $0 : nil }
            try executePrepared(
                "UPDATE categories SET parent_id = ? WHERE id = ?",
                bindings: [.nullableText(parentId), .text(category.id)]
            )
        }
    }

    private func upsertTransactions(
        _ transactions: [DraftTransaction],
        deletedKeysById: [String: TransactionOpSortKey]
    ) throws {
        let currentIds = Set(transactions.map(\.id))
        for transaction in transactions {
            let locationJSON = try transaction.location.map { location -> String in
                String(data: try Self.encoder.encode(location), encoding: .utf8) ?? "{}"
            }
            try executePrepared(
                """
                INSERT INTO transactions (
                    id, kind, amount_text, transfer_in_amount_text, category_id,
                    account_id, from_account_id, to_account_id, date, note,
                    location_json, created_at, deleted_at
                )
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NULL)
                ON CONFLICT(id) DO UPDATE SET
                    kind = excluded.kind,
                    amount_text = excluded.amount_text,
                    transfer_in_amount_text = excluded.transfer_in_amount_text,
                    category_id = excluded.category_id,
                    account_id = excluded.account_id,
                    from_account_id = excluded.from_account_id,
                    to_account_id = excluded.to_account_id,
                    date = excluded.date,
                    note = excluded.note,
                    location_json = excluded.location_json,
                    created_at = excluded.created_at,
                    deleted_at = NULL
                """,
                bindings: [
                    .text(transaction.id),
                    .text(transaction.kind.rawValue),
                    .text(transaction.amountText),
                    .nullableText(transaction.transferInAmountText),
                    .nullableText(transaction.categoryId),
                    .nullableText(transaction.accountId),
                    .nullableText(transaction.fromAccountId),
                    .nullableText(transaction.toAccountId),
                    .text(Self.isoString(from: transaction.date)),
                    .text(transaction.note),
                    .nullableText(locationJSON),
                    .text(Self.isoString(from: transaction.createdAt))
                ]
            )
        }

        for (id, key) in deletedKeysById where !currentIds.contains(id) {
            try executePrepared(
                "UPDATE transactions SET deleted_at = ? WHERE id = ?",
                bindings: [.text(Self.isoString(from: key.occurredAt)), .text(id)]
            )
        }
    }

    private func upsertTemplates(
        _ templates: [DraftTransactionTemplate],
        deletedKeysById: [String: TemplateOpSortKey]
    ) throws {
        let currentIds = Set(templates.map(\.id))
        for template in templates {
            try executePrepared(
                """
                INSERT INTO transaction_templates (
                    id, name, kind, amount_text, category_id, account_id,
                    note, created_at, updated_at, deleted_at
                )
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, NULL)
                ON CONFLICT(id) DO UPDATE SET
                    name = excluded.name,
                    kind = excluded.kind,
                    amount_text = excluded.amount_text,
                    category_id = excluded.category_id,
                    account_id = excluded.account_id,
                    note = excluded.note,
                    created_at = excluded.created_at,
                    updated_at = excluded.updated_at,
                    deleted_at = NULL
                """,
                bindings: [
                    .text(template.id),
                    .text(template.name),
                    .text(template.kind.rawValue),
                    .text(template.amountText),
                    .text(template.categoryId),
                    .text(template.accountId),
                    .text(template.note),
                    .text(Self.isoString(from: template.createdAt)),
                    .text(Self.isoString(from: template.updatedAt))
                ]
            )
        }

        for (id, key) in deletedKeysById where !currentIds.contains(id) {
            try executePrepared(
                "UPDATE transaction_templates SET deleted_at = ? WHERE id = ?",
                bindings: [.text(Self.isoString(from: key.occurredAt)), .text(id)]
            )
        }
    }

    private func upsertBudgets(_ budgets: [DraftBudget], deletedKeysById: [String: BudgetOpSortKey]) throws {
        let currentIds = Set(budgets.map(\.id))
        for budget in budgets {
            try executePrepared(
                """
                INSERT INTO budgets (
                    id, name, scope, target_id, amount_text,
                    is_enabled, created_at, updated_at, deleted_at
                )
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, NULL)
                ON CONFLICT(id) DO UPDATE SET
                    name = excluded.name,
                    scope = excluded.scope,
                    target_id = excluded.target_id,
                    amount_text = excluded.amount_text,
                    is_enabled = excluded.is_enabled,
                    created_at = excluded.created_at,
                    updated_at = excluded.updated_at,
                    deleted_at = NULL
                """,
                bindings: [
                    .text(budget.id),
                    .text(budget.name),
                    .text(budget.scope.rawValue),
                    .nullableText(budget.targetId),
                    .text(budget.amountText),
                    .int(budget.isEnabled ? 1 : 0),
                    .text(Self.isoString(from: budget.createdAt)),
                    .text(Self.isoString(from: budget.updatedAt))
                ]
            )
        }

        for (id, key) in deletedKeysById where !currentIds.contains(id) {
            try executePrepared(
                "UPDATE budgets SET deleted_at = ? WHERE id = ?",
                bindings: [.text(Self.isoString(from: key.occurredAt)), .text(id)]
            )
        }
    }

    private func pruneRemovedAccounts(keeping currentIds: Set<String>) throws {
        for existingId in try readIds(from: "accounts") where !currentIds.contains(existingId) {
            if try !accountIsReferenced(existingId) {
                try executePrepared("DELETE FROM accounts WHERE id = ?", bindings: [.text(existingId)])
            }
        }
    }

    private func pruneRemovedCategories(keeping currentIds: Set<String>) throws {
        for existingId in try readIds(from: "categories") where !currentIds.contains(existingId) {
            if try !categoryIsReferenced(existingId) {
                try executePrepared("DELETE FROM categories WHERE id = ?", bindings: [.text(existingId)])
            }
        }
    }

    private func replaceLocalSyncOps(_ snapshot: LedgerSnapshot) throws {
        try execute("DELETE FROM sync_ops WHERE source = 'local'")
        for op in snapshot.localMetadataOps {
            try insertSyncOp(
                domain: .metadata,
                schemaVersion: op.schemaVersion,
                ledgerId: op.ledgerId,
                deviceId: op.deviceId,
                seq: op.seq,
                entity: op.entity.rawValue,
                entityId: op.entityId,
                action: op.action.rawValue,
                occurredAt: op.occurredAt,
                createdAt: op.createdAt,
                payload: op.payload,
                uploadedAt: snapshot.uploadedMetadataOpIds.contains(op.opId) ? Date() : nil,
                source: "local",
                opId: op.opId
            )
        }
        for op in snapshot.localTransactionOps {
            try insertSyncOp(
                domain: .transactions,
                schemaVersion: op.schemaVersion,
                ledgerId: op.ledgerId,
                deviceId: op.deviceId,
                seq: op.seq,
                entity: op.entity,
                entityId: op.entityId,
                action: op.action.rawValue,
                occurredAt: op.occurredAt,
                createdAt: op.createdAt,
                payload: op.payload,
                uploadedAt: snapshot.uploadedTransactionOpIds.contains(op.opId) ? Date() : nil,
                source: "local",
                opId: op.opId
            )
        }
        for op in snapshot.localTemplateOps {
            try insertSyncOp(
                domain: .templates,
                schemaVersion: op.schemaVersion,
                ledgerId: op.ledgerId,
                deviceId: op.deviceId,
                seq: op.seq,
                entity: op.entity,
                entityId: op.entityId,
                action: op.action.rawValue,
                occurredAt: op.occurredAt,
                createdAt: op.createdAt,
                payload: op.payload,
                uploadedAt: snapshot.uploadedTemplateOpIds.contains(op.opId) ? Date() : nil,
                source: "local",
                opId: op.opId
            )
        }
        for op in snapshot.localBudgetOps {
            try insertSyncOp(
                domain: .budgets,
                schemaVersion: op.schemaVersion,
                ledgerId: op.ledgerId,
                deviceId: op.deviceId,
                seq: op.seq,
                entity: op.entity,
                entityId: op.entityId,
                action: op.action.rawValue,
                occurredAt: op.occurredAt,
                createdAt: op.createdAt,
                payload: op.payload,
                uploadedAt: snapshot.uploadedBudgetOpIds.contains(op.opId) ? Date() : nil,
                source: "local",
                opId: op.opId
            )
        }
    }

    private func upsertProcessedOps(_ snapshot: LedgerSnapshot) throws {
        let metadataOpsById = Dictionary(uniqueKeysWithValues: snapshot.localMetadataOps.map { ($0.opId, $0) })
        for opId in snapshot.processedMetadataOpIds {
            if let op = metadataOpsById[opId] {
                try upsertProcessedOp(opId: opId, domain: .metadata, deviceId: op.deviceId, seq: op.seq, applied: true)
            } else {
                try upsertProcessedOp(opId: opId, domain: .metadata, deviceId: "", seq: 0, applied: true)
            }
        }
        let transactionOpsById = Dictionary(uniqueKeysWithValues: snapshot.localTransactionOps.map { ($0.opId, $0) })
        for opId in snapshot.processedTransactionOpIds {
            if let op = transactionOpsById[opId] {
                try upsertProcessedOp(opId: opId, domain: .transactions, deviceId: op.deviceId, seq: op.seq, applied: true)
            } else {
                try upsertProcessedOp(opId: opId, domain: .transactions, deviceId: "", seq: 0, applied: true)
            }
        }
        let templateOpsById = Dictionary(uniqueKeysWithValues: snapshot.localTemplateOps.map { ($0.opId, $0) })
        for opId in snapshot.processedTemplateOpIds {
            if let op = templateOpsById[opId] {
                try upsertProcessedOp(opId: opId, domain: .templates, deviceId: op.deviceId, seq: op.seq, applied: true)
            } else {
                try upsertProcessedOp(opId: opId, domain: .templates, deviceId: "", seq: 0, applied: true)
            }
        }
        let budgetOpsById = Dictionary(uniqueKeysWithValues: snapshot.localBudgetOps.map { ($0.opId, $0) })
        for opId in snapshot.processedBudgetOpIds {
            if let op = budgetOpsById[opId] {
                try upsertProcessedOp(opId: opId, domain: .budgets, deviceId: op.deviceId, seq: op.seq, applied: true)
            } else {
                try upsertProcessedOp(opId: opId, domain: .budgets, deviceId: "", seq: 0, applied: true)
            }
        }
    }

    private func replaceEntitySyncState(_ snapshot: LedgerSnapshot) throws {
        try execute("DELETE FROM entity_sync_state")
        for (key, sortKey) in snapshot.metadataOpSortKeysById {
            let parts = metadataStateParts(from: key)
            try upsertEntityState(domain: .metadata, entity: parts.entity, entityId: parts.id, current: sortKey, deleted: snapshot.deletedMetadataOpSortKeysById[key])
        }
        for (key, deletedKey) in snapshot.deletedMetadataOpSortKeysById where snapshot.metadataOpSortKeysById[key] == nil {
            let parts = metadataStateParts(from: key)
            try upsertEntityState(domain: .metadata, entity: parts.entity, entityId: parts.id, current: nil as MetadataOpSortKey?, deleted: deletedKey)
        }
        try replaceSimpleEntityState(
            domain: .transactions,
            entity: "transaction",
            current: snapshot.transactionOpSortKeysById,
            deleted: snapshot.deletedTransactionOpSortKeysById
        )
        try replaceSimpleEntityState(
            domain: .templates,
            entity: "transactionTemplate",
            current: snapshot.templateOpSortKeysById,
            deleted: snapshot.deletedTemplateOpSortKeysById
        )
        try replaceSimpleEntityState(
            domain: .budgets,
            entity: "budget",
            current: snapshot.budgetOpSortKeysById,
            deleted: snapshot.deletedBudgetOpSortKeysById
        )
    }

    private func replaceSimpleEntityState<Key: LedgerSortKeyConvertible>(
        domain: LedgerSyncDomain,
        entity: String,
        current: [String: Key],
        deleted: [String: Key]
    ) throws {
        for (id, sortKey) in current {
            try upsertEntityState(domain: domain, entity: entity, entityId: id, current: sortKey, deleted: deleted[id])
        }
        for (id, sortKey) in deleted where current[id] == nil {
            try upsertEntityState(domain: domain, entity: entity, entityId: id, current: nil as Key?, deleted: sortKey)
        }
    }

    private func replaceSyncCursors(_ snapshot: LedgerSnapshot) throws {
        try execute("DELETE FROM sync_cursors")
        try upsertSyncCursors(domain: .metadata, cursors: snapshot.importedMetadataSeqByDeviceId)
        try upsertSyncCursors(domain: .transactions, cursors: snapshot.importedTransactionSeqByDeviceId)
        try upsertSyncCursors(domain: .templates, cursors: snapshot.importedTemplateSeqByDeviceId)
        try upsertSyncCursors(domain: .budgets, cursors: snapshot.importedBudgetSeqByDeviceId)
    }

    private func persistLedgerMetadata(_ snapshot: LedgerSnapshot) throws {
        try writeMetadata(.metadataRevision, value: snapshot.metadataRevision)
        try writeMetadata(.metadataUpdatedAt, value: Self.isoString(from: snapshot.metadataUpdatedAt))
        try writeMetadata(.metadataUpdatedByDeviceId, value: snapshot.metadataUpdatedByDeviceId)
        try writeMetadata(.metadataNextSeq, value: snapshot.nextMetadataOpSeq)
        try writeMetadata(.transactionsRevision, value: snapshot.transactionsRevision)
        try writeMetadata(.transactionsUpdatedAt, value: Self.isoString(from: snapshot.transactionsUpdatedAt))
        try writeMetadata(.transactionsUpdatedByDeviceId, value: snapshot.transactionsUpdatedByDeviceId)
        try writeMetadata(.transactionNextSeq, value: snapshot.nextTransactionOpSeq)
        try writeMetadata(.templateNextSeq, value: snapshot.nextTemplateOpSeq)
        try writeMetadata(.budgetNextSeq, value: snapshot.nextBudgetOpSeq)
    }

    private func readAccounts() throws -> [DraftAccount] {
        let statement = try prepare(
            """
            SELECT id, name, is_default, type, icon_name, color_hex, balance_text, note, archived_at
            FROM accounts
            ORDER BY rowid
            """
        )
        defer { sqlite3_finalize(statement) }

        var accounts: [DraftAccount] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            accounts.append(
                DraftAccount(
                    id: columnText(statement, 0),
                    name: columnText(statement, 1),
                    isDefault: sqlite3_column_int(statement, 2) != 0,
                    type: DraftAccountType(persistedValue: columnText(statement, 3)),
                    iconName: columnText(statement, 4),
                    colorHex: columnText(statement, 5),
                    balanceText: columnText(statement, 6),
                    note: columnText(statement, 7),
                    archivedAt: columnDate(statement, 8)
                )
            )
        }
        return accounts
    }

    private func readAccountBaseBalances() throws -> [String: String] {
        let statement = try prepare("SELECT id, base_balance_text FROM accounts")
        defer { sqlite3_finalize(statement) }

        var values: [String: String] = [:]
        while sqlite3_step(statement) == SQLITE_ROW {
            values[columnText(statement, 0)] = columnText(statement, 1)
        }
        return values
    }

    private func readCategories() throws -> [DraftCategory] {
        let statement = try prepare(
            """
            SELECT id, name, is_default, kind, parent_id, icon_name, color_hex, archived_at
            FROM categories
            ORDER BY rowid
            """
        )
        defer { sqlite3_finalize(statement) }

        var categories: [DraftCategory] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            categories.append(
                DraftCategory(
                    id: columnText(statement, 0),
                    name: columnText(statement, 1),
                    isDefault: sqlite3_column_int(statement, 2) != 0,
                    kind: DraftEntryKind(rawValue: columnText(statement, 3)) ?? .expense,
                    parentId: columnOptionalText(statement, 4),
                    iconName: columnText(statement, 5),
                    colorHex: columnText(statement, 6),
                    archivedAt: columnDate(statement, 7)
                )
            )
        }
        return categories
    }

    private func readTransactions() throws -> [DraftTransaction] {
        let statement = try prepare(
            """
            SELECT id, kind, amount_text, transfer_in_amount_text, category_id,
                   account_id, from_account_id, to_account_id, date, note,
                   location_json, created_at
            FROM transactions
            WHERE deleted_at IS NULL
            ORDER BY date DESC, created_at DESC
            """
        )
        defer { sqlite3_finalize(statement) }

        var transactions: [DraftTransaction] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            let location: DraftLocation?
            if let locationJSON = columnOptionalText(statement, 10), let data = locationJSON.data(using: .utf8) {
                location = try? Self.decoder.decode(DraftLocation.self, from: data)
            } else {
                location = nil
            }
            transactions.append(
                DraftTransaction(
                    id: columnText(statement, 0),
                    kind: DraftEntryKind(rawValue: columnText(statement, 1)) ?? .expense,
                    amountText: columnText(statement, 2),
                    transferInAmountText: columnOptionalText(statement, 3),
                    categoryId: columnOptionalText(statement, 4),
                    accountId: columnOptionalText(statement, 5),
                    fromAccountId: columnOptionalText(statement, 6),
                    toAccountId: columnOptionalText(statement, 7),
                    date: columnDate(statement, 8) ?? Date(timeIntervalSince1970: 0),
                    note: columnText(statement, 9),
                    location: location,
                    createdAt: columnDate(statement, 11) ?? Date(timeIntervalSince1970: 0)
                )
            )
        }
        return transactions
    }

    private func readTemplates() throws -> [DraftTransactionTemplate] {
        let statement = try prepare(
            """
            SELECT id, name, kind, amount_text, category_id, account_id, note, created_at, updated_at
            FROM transaction_templates
            WHERE deleted_at IS NULL
            ORDER BY updated_at DESC, created_at DESC
            """
        )
        defer { sqlite3_finalize(statement) }

        var templates: [DraftTransactionTemplate] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            templates.append(
                DraftTransactionTemplate(
                    id: columnText(statement, 0),
                    name: columnText(statement, 1),
                    kind: DraftEntryKind(rawValue: columnText(statement, 2)) ?? .expense,
                    amountText: columnText(statement, 3),
                    categoryId: columnText(statement, 4),
                    accountId: columnText(statement, 5),
                    note: columnText(statement, 6),
                    createdAt: columnDate(statement, 7) ?? Date(timeIntervalSince1970: 0),
                    updatedAt: columnDate(statement, 8) ?? Date(timeIntervalSince1970: 0)
                )
            )
        }
        return templates
    }

    private func readBudgets() throws -> [DraftBudget] {
        let statement = try prepare(
            """
            SELECT id, name, scope, target_id, amount_text, is_enabled, created_at, updated_at
            FROM budgets
            WHERE deleted_at IS NULL
            ORDER BY is_enabled DESC, updated_at DESC, created_at DESC
            """
        )
        defer { sqlite3_finalize(statement) }

        var budgets: [DraftBudget] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            budgets.append(
                DraftBudget(
                    id: columnText(statement, 0),
                    name: columnText(statement, 1),
                    scope: DraftBudgetScope(rawValue: columnText(statement, 2)) ?? .overall,
                    targetId: columnOptionalText(statement, 3),
                    amountText: columnText(statement, 4),
                    isEnabled: sqlite3_column_int(statement, 5) != 0,
                    createdAt: columnDate(statement, 6) ?? Date(timeIntervalSince1970: 0),
                    updatedAt: columnDate(statement, 7) ?? Date(timeIntervalSince1970: 0)
                )
            )
        }
        return budgets
    }

    private func readMetadataOps(pendingOnly: Bool) throws -> [BookkeepingMetadataOp] {
        try readSyncRows(domain: .metadata, pendingOnly: pendingOnly).compactMap { row in
            guard
                let entity = BookkeepingMetadataEntity(rawValue: row.entity),
                let action = BookkeepingMetadataOpAction(rawValue: row.action)
            else {
                return nil
            }
            let payload: BookkeepingMetadataOpPayload?
            if let payloadJSON = row.payloadJSON, let data = payloadJSON.data(using: .utf8) {
                payload = try? Self.decoder.decode(BookkeepingMetadataOpPayload.self, from: data)
            } else {
                payload = nil
            }
            return BookkeepingMetadataOp(
                opId: row.opId,
                ledgerId: row.ledgerId,
                deviceId: row.deviceId,
                seq: row.seq,
                entity: entity,
                entityId: row.entityId,
                action: action,
                occurredAt: row.occurredAt,
                createdAt: row.createdAt,
                payload: payload
            )
        }
    }

    private func readTransactionOps(pendingOnly: Bool) throws -> [BookkeepingTransactionOp] {
        try readSyncRows(domain: .transactions, pendingOnly: pendingOnly).compactMap { row in
            guard let action = BookkeepingTransactionOpAction(rawValue: row.action) else { return nil }
            let payload: DraftTransaction?
            if let payloadJSON = row.payloadJSON, let data = payloadJSON.data(using: .utf8) {
                payload = try? Self.decoder.decode(DraftTransaction.self, from: data)
            } else {
                payload = nil
            }
            return BookkeepingTransactionOp(
                opId: row.opId,
                ledgerId: row.ledgerId,
                deviceId: row.deviceId,
                seq: row.seq,
                entityId: row.entityId,
                action: action,
                occurredAt: row.occurredAt,
                createdAt: row.createdAt,
                payload: payload
            )
        }
    }

    private func readTemplateOps(pendingOnly: Bool) throws -> [BookkeepingTemplateOp] {
        try readSyncRows(domain: .templates, pendingOnly: pendingOnly).compactMap { row in
            guard let action = BookkeepingTemplateOpAction(rawValue: row.action) else { return nil }
            let payload: DraftTransactionTemplate?
            if let payloadJSON = row.payloadJSON, let data = payloadJSON.data(using: .utf8) {
                payload = try? Self.decoder.decode(DraftTransactionTemplate.self, from: data)
            } else {
                payload = nil
            }
            return BookkeepingTemplateOp(
                opId: row.opId,
                ledgerId: row.ledgerId,
                deviceId: row.deviceId,
                seq: row.seq,
                entityId: row.entityId,
                action: action,
                occurredAt: row.occurredAt,
                createdAt: row.createdAt,
                payload: payload
            )
        }
    }

    private func readBudgetOps(pendingOnly: Bool) throws -> [BookkeepingBudgetOp] {
        try readSyncRows(domain: .budgets, pendingOnly: pendingOnly).compactMap { row in
            guard let action = BookkeepingBudgetOpAction(rawValue: row.action) else { return nil }
            let payload: DraftBudget?
            if let payloadJSON = row.payloadJSON, let data = payloadJSON.data(using: .utf8) {
                payload = try? Self.decoder.decode(DraftBudget.self, from: data)
            } else {
                payload = nil
            }
            return BookkeepingBudgetOp(
                opId: row.opId,
                ledgerId: row.ledgerId,
                deviceId: row.deviceId,
                seq: row.seq,
                entityId: row.entityId,
                action: action,
                occurredAt: row.occurredAt,
                createdAt: row.createdAt,
                payload: payload
            )
        }
    }

    private func readSyncRows(domain: LedgerSyncDomain, pendingOnly: Bool) throws -> [SyncOpRow] {
        let sql =
            """
            SELECT op_id, schema_version, ledger_id, device_id, seq, entity, entity_id,
                   action, occurred_at, created_at, payload_json
            FROM sync_ops
            WHERE domain = ? AND source = 'local'
            \(pendingOnly ? "AND uploaded_at IS NULL" : "")
            ORDER BY created_at ASC, device_id ASC, seq ASC
            """
        let statement = try prepare(sql)
        defer { sqlite3_finalize(statement) }

        bindText(domain.rawValue, to: statement, index: 1)

        var rows: [SyncOpRow] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            rows.append(
                SyncOpRow(
                    opId: columnText(statement, 0),
                    schemaVersion: Int(sqlite3_column_int(statement, 1)),
                    ledgerId: columnText(statement, 2),
                    deviceId: columnText(statement, 3),
                    seq: Int(sqlite3_column_int64(statement, 4)),
                    entity: columnText(statement, 5),
                    entityId: columnText(statement, 6),
                    action: columnText(statement, 7),
                    occurredAt: columnDate(statement, 8) ?? Date(timeIntervalSince1970: 0),
                    createdAt: columnDate(statement, 9) ?? Date(timeIntervalSince1970: 0),
                    payloadJSON: columnOptionalText(statement, 10)
                )
            )
        }
        return rows
    }

    private func recordRemoteOp<Payload: Encodable>(
        opId: String,
        domain: LedgerSyncDomain,
        schemaVersion: Int,
        ledgerId: String,
        deviceId: String,
        seq: Int,
        entity: String,
        entityId: String,
        action: String,
        occurredAt: Date,
        createdAt: Date,
        payload: Payload?
    ) {
        do {
            try ensureNormalizedSchema()
            try insertSyncOp(
                domain: domain,
                schemaVersion: schemaVersion,
                ledgerId: ledgerId,
                deviceId: deviceId,
                seq: seq,
                entity: entity,
                entityId: entityId,
                action: action,
                occurredAt: occurredAt,
                createdAt: createdAt,
                payload: payload,
                uploadedAt: nil,
                source: "remote",
                opId: opId
            )
        } catch {
            assertionFailure("Failed to record remote SQLite sync op: \(error)")
        }
    }

    private func insertSyncOp<Payload: Encodable>(
        domain: LedgerSyncDomain,
        schemaVersion: Int,
        ledgerId: String,
        deviceId: String,
        seq: Int,
        entity: String,
        entityId: String,
        action: String,
        occurredAt: Date,
        createdAt: Date,
        payload: Payload?,
        uploadedAt: Date?,
        source: String,
        opId: String
    ) throws {
        let payloadJSON: String?
        if let payload {
            payloadJSON = String(data: try Self.encoder.encode(payload), encoding: .utf8)
        } else {
            payloadJSON = nil
        }

        try executePrepared(
            """
            INSERT OR REPLACE INTO sync_ops (
                op_id, domain, schema_version, ledger_id, device_id, seq,
                entity, entity_id, action, occurred_at, created_at,
                payload_json, uploaded_at, source
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            bindings: [
                .text(opId),
                .text(domain.rawValue),
                .int(schemaVersion),
                .text(ledgerId),
                .text(deviceId),
                .int(seq),
                .text(entity),
                .text(entityId),
                .text(action),
                .text(Self.isoString(from: occurredAt)),
                .text(Self.isoString(from: createdAt)),
                .nullableText(payloadJSON),
                .nullableText(uploadedAt.map(Self.isoString)),
                .text(source)
            ]
        )
    }

    private func upsertProcessedOp(
        opId: String,
        domain: LedgerSyncDomain,
        deviceId: String,
        seq: Int,
        applied: Bool,
        skippedReason: String? = nil,
        processedAt: Date = Date()
    ) throws {
        try executePrepared(
            """
            INSERT INTO processed_ops (
                op_id, domain, device_id, seq, processed_at, applied, skipped_reason
            )
            VALUES (?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(op_id) DO UPDATE SET
                processed_at = excluded.processed_at,
                applied = CASE
                    WHEN processed_ops.applied = 0 THEN processed_ops.applied
                    ELSE excluded.applied
                END,
                skipped_reason = COALESCE(processed_ops.skipped_reason, excluded.skipped_reason)
            """,
            bindings: [
                .text(opId),
                .text(domain.rawValue),
                .text(deviceId),
                .int(seq),
                .text(Self.isoString(from: processedAt)),
                .int(applied ? 1 : 0),
                .nullableText(skippedReason)
            ]
        )
    }

    private func upsertEntityState<Key: LedgerSortKeyConvertible>(
        domain: LedgerSyncDomain,
        entity: String,
        entityId: String,
        current: Key?,
        deleted: Key?
    ) throws {
        try executePrepared(
            """
            INSERT INTO entity_sync_state (
                domain, entity, entity_id,
                current_occurred_at, current_device_id, current_seq,
                deleted_occurred_at, deleted_device_id, deleted_seq
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(domain, entity, entity_id) DO UPDATE SET
                current_occurred_at = excluded.current_occurred_at,
                current_device_id = excluded.current_device_id,
                current_seq = excluded.current_seq,
                deleted_occurred_at = excluded.deleted_occurred_at,
                deleted_device_id = excluded.deleted_device_id,
                deleted_seq = excluded.deleted_seq
            """,
            bindings: [
                .text(domain.rawValue),
                .text(entity),
                .text(entityId),
                .nullableText(current.map { Self.isoString(from: $0.occurredAt) }),
                .nullableText(current?.deviceId),
                .nullableInt(current?.seq),
                .nullableText(deleted.map { Self.isoString(from: $0.occurredAt) }),
                .nullableText(deleted?.deviceId),
                .nullableInt(deleted?.seq)
            ]
        )
    }

    private func upsertSyncCursors(domain: LedgerSyncDomain, cursors: [String: Int]) throws {
        let now = Self.isoString(from: Date())
        for (deviceId, lastSeq) in cursors {
            try executePrepared(
                """
                INSERT INTO sync_cursors (domain, remote_device_id, last_seq, updated_at)
                VALUES (?, ?, ?, ?)
                ON CONFLICT(domain, remote_device_id) DO UPDATE SET
                    last_seq = excluded.last_seq,
                    updated_at = excluded.updated_at
                """,
                bindings: [.text(domain.rawValue), .text(deviceId), .int(lastSeq), .text(now)]
            )
        }
    }

    private func readUploadedOpIds(domain: LedgerSyncDomain) throws -> Set<String> {
        let statement = try prepare(
            "SELECT op_id FROM sync_ops WHERE domain = ? AND source = 'local' AND uploaded_at IS NOT NULL"
        )
        defer { sqlite3_finalize(statement) }
        bindText(domain.rawValue, to: statement, index: 1)

        var ids = Set<String>()
        while sqlite3_step(statement) == SQLITE_ROW {
            ids.insert(columnText(statement, 0))
        }
        return ids
    }

    private func readProcessedOpIds(domain: LedgerSyncDomain) throws -> Set<String> {
        let statement = try prepare("SELECT op_id FROM processed_ops WHERE domain = ?")
        defer { sqlite3_finalize(statement) }
        bindText(domain.rawValue, to: statement, index: 1)

        var ids = Set<String>()
        while sqlite3_step(statement) == SQLITE_ROW {
            ids.insert(columnText(statement, 0))
        }
        return ids
    }

    private func readSyncCursors(domain: LedgerSyncDomain) throws -> [String: Int] {
        let statement = try prepare("SELECT remote_device_id, last_seq FROM sync_cursors WHERE domain = ?")
        defer { sqlite3_finalize(statement) }
        bindText(domain.rawValue, to: statement, index: 1)

        var cursors: [String: Int] = [:]
        while sqlite3_step(statement) == SQLITE_ROW {
            cursors[columnText(statement, 0)] = Int(sqlite3_column_int64(statement, 1))
        }
        return cursors
    }

    private func readMetadataEntityStates() throws -> (
        current: [String: MetadataOpSortKey],
        deleted: [String: MetadataOpSortKey]
    ) {
        let statement = try prepare(
            """
            SELECT entity, entity_id, current_occurred_at, current_device_id, current_seq,
                   deleted_occurred_at, deleted_device_id, deleted_seq
            FROM entity_sync_state
            WHERE domain = ?
            """
        )
        defer { sqlite3_finalize(statement) }
        bindText(LedgerSyncDomain.metadata.rawValue, to: statement, index: 1)

        var current: [String: MetadataOpSortKey] = [:]
        var deleted: [String: MetadataOpSortKey] = [:]
        while sqlite3_step(statement) == SQLITE_ROW {
            let key = "\(columnText(statement, 0)):\(columnText(statement, 1))"
            if let currentKey = sortKey(statement, dateIndex: 2, deviceIndex: 3, seqIndex: 4) {
                current[key] = MetadataOpSortKey(occurredAt: currentKey.occurredAt, deviceId: currentKey.deviceId, seq: currentKey.seq)
            }
            if let deletedKey = sortKey(statement, dateIndex: 5, deviceIndex: 6, seqIndex: 7) {
                deleted[key] = MetadataOpSortKey(occurredAt: deletedKey.occurredAt, deviceId: deletedKey.deviceId, seq: deletedKey.seq)
            }
        }
        return (current, deleted)
    }

    private func readSimpleEntityStates(domain: LedgerSyncDomain) throws -> (
        current: [String: SimpleSortKey],
        deleted: [String: SimpleSortKey]
    ) {
        let statement = try prepare(
            """
            SELECT entity_id, current_occurred_at, current_device_id, current_seq,
                   deleted_occurred_at, deleted_device_id, deleted_seq
            FROM entity_sync_state
            WHERE domain = ?
            """
        )
        defer { sqlite3_finalize(statement) }
        bindText(domain.rawValue, to: statement, index: 1)

        var current: [String: SimpleSortKey] = [:]
        var deleted: [String: SimpleSortKey] = [:]
        while sqlite3_step(statement) == SQLITE_ROW {
            let id = columnText(statement, 0)
            if let currentKey = sortKey(statement, dateIndex: 1, deviceIndex: 2, seqIndex: 3) {
                current[id] = currentKey
            }
            if let deletedKey = sortKey(statement, dateIndex: 4, deviceIndex: 5, seqIndex: 6) {
                deleted[id] = deletedKey
            }
        }
        return (current, deleted)
    }

    private func sortKey(_ statement: OpaquePointer?, dateIndex: Int32, deviceIndex: Int32, seqIndex: Int32) -> SimpleSortKey? {
        guard
            let date = columnDate(statement, dateIndex),
            let deviceId = columnOptionalText(statement, deviceIndex)
        else {
            return nil
        }
        return SimpleSortKey(occurredAt: date, deviceId: deviceId, seq: Int(sqlite3_column_int64(statement, seqIndex)))
    }

    private func readIds(from table: String) throws -> [String] {
        let statement = try prepare("SELECT id FROM \(table)")
        defer { sqlite3_finalize(statement) }

        var ids: [String] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            ids.append(columnText(statement, 0))
        }
        return ids
    }

    private func accountIsReferenced(_ id: String) throws -> Bool {
        try exists(
            """
            SELECT 1 FROM transactions
            WHERE deleted_at IS NULL
              AND (account_id = ? OR from_account_id = ? OR to_account_id = ?)
            LIMIT 1
            """,
            bindings: [.text(id), .text(id), .text(id)]
        )
    }

    private func categoryIsReferenced(_ id: String) throws -> Bool {
        try exists(
            """
            SELECT 1 FROM transactions
            WHERE deleted_at IS NULL AND category_id = ?
            LIMIT 1
            """,
            bindings: [.text(id)]
        )
    }

    private func exists(_ sql: String, bindings: [SQLiteBinding]) throws -> Bool {
        let statement = try prepare(sql)
        defer { sqlite3_finalize(statement) }
        try bind(bindings, to: statement)
        return sqlite3_step(statement) == SQLITE_ROW
    }

    private func metadataStateParts(from key: String) -> (entity: String, id: String) {
        let parts = key.split(separator: ":", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return ("", key) }
        return (parts[0], parts[1])
    }

    private func readMetadataString(_ key: LedgerMetadataKey) -> String? {
        do {
            let statement = try prepare("SELECT value FROM ledger_metadata WHERE key = ? LIMIT 1")
            defer { sqlite3_finalize(statement) }
            bindText(key.rawValue, to: statement, index: 1)
            guard sqlite3_step(statement) == SQLITE_ROW else { return nil }
            return columnText(statement, 0)
        } catch {
            return nil
        }
    }

    private func readMetadataInt(_ key: LedgerMetadataKey) -> Int? {
        guard let value = readMetadataString(key) else { return nil }
        return Int(value)
    }

    private func readMetadataDate(_ key: LedgerMetadataKey) -> Date? {
        guard let value = readMetadataString(key) else { return nil }
        return Self.isoFormatter.date(from: value)
    }

    private func writeMetadata(_ key: LedgerMetadataKey, value: Int) throws {
        try writeMetadata(key, value: String(value))
    }

    private func writeMetadata(_ key: LedgerMetadataKey, value: String) throws {
        try executePrepared(
            """
            INSERT INTO ledger_metadata (key, value, updated_at)
            VALUES (?, ?, ?)
            ON CONFLICT(key) DO UPDATE SET
                value = excluded.value,
                updated_at = excluded.updated_at
            """,
            bindings: [.text(key.rawValue), .text(value), .text(Self.isoString(from: Date()))]
        )
    }

    private func transaction(_ body: () throws -> Void) throws {
        try execute("BEGIN IMMEDIATE TRANSACTION")
        do {
            try body()
            try execute("COMMIT")
        } catch {
            try? execute("ROLLBACK")
            throw error
        }
    }

    private func execute(_ sql: String) throws {
        guard let db else { return }
        if sqlite3_exec(db, sql, nil, nil, nil) != SQLITE_OK {
            throw StoreError.stepFailed(lastErrorMessage)
        }
    }

    private func executePrepared(_ sql: String, bindings: [SQLiteBinding]) throws {
        let statement = try prepare(sql)
        defer { sqlite3_finalize(statement) }
        try bind(bindings, to: statement)
        let result = sqlite3_step(statement)
        guard result == SQLITE_DONE || result == SQLITE_ROW else {
            throw StoreError.stepFailed(lastErrorMessage)
        }
    }

    private func prepare(_ sql: String) throws -> OpaquePointer? {
        guard let db else { return nil }
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw StoreError.prepareFailed(lastErrorMessage)
        }
        return statement
    }

    private func bind(_ bindings: [SQLiteBinding], to statement: OpaquePointer?) throws {
        for (offset, binding) in bindings.enumerated() {
            let index = Int32(offset + 1)
            switch binding {
            case .text(let value):
                bindText(value, to: statement, index: index)
            case .nullableText(let value):
                if let value {
                    bindText(value, to: statement, index: index)
                } else {
                    sqlite3_bind_null(statement, index)
                }
            case .int(let value):
                sqlite3_bind_int64(statement, index, sqlite3_int64(value))
            case .nullableInt(let value):
                if let value {
                    sqlite3_bind_int64(statement, index, sqlite3_int64(value))
                } else {
                    sqlite3_bind_null(statement, index)
                }
            }
        }
    }

    private func bindText(_ value: String, to statement: OpaquePointer?, index: Int32) {
        sqlite3_bind_text(statement, index, value, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
    }

    private func columnText(_ statement: OpaquePointer?, _ index: Int32) -> String {
        guard let text = sqlite3_column_text(statement, index) else { return "" }
        return String(cString: text)
    }

    private func columnOptionalText(_ statement: OpaquePointer?, _ index: Int32) -> String? {
        guard sqlite3_column_type(statement, index) != SQLITE_NULL else { return nil }
        return columnText(statement, index)
    }

    private func columnDate(_ statement: OpaquePointer?, _ index: Int32) -> Date? {
        guard let text = columnOptionalText(statement, index) else { return nil }
        return Self.isoFormatter.date(from: text)
    }

    private var userVersion: Int {
        guard let db else { return 0 }
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, "PRAGMA user_version", -1, &statement, nil) == SQLITE_OK else {
            return 0
        }
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_ROW else { return 0 }
        return Int(sqlite3_column_int(statement, 0))
    }

    private func setUserVersion(_ version: Int) throws {
        try execute("PRAGMA user_version = \(version)")
    }

    private static func isoString(from date: Date) -> String {
        isoFormatter.string(from: date)
    }

    private var lastErrorMessage: String {
        guard let db, let message = sqlite3_errmsg(db) else {
            return "Unknown SQLite error"
        }

        return String(cString: message)
    }
}

private enum LedgerMetadataKey: String {
    case metadataRevision = "metadata.revision"
    case metadataUpdatedAt = "metadata.updatedAt"
    case metadataUpdatedByDeviceId = "metadata.updatedByDeviceId"
    case metadataNextSeq = "metadata.nextSeq"
    case transactionsRevision = "transactions.revision"
    case transactionsUpdatedAt = "transactions.updatedAt"
    case transactionsUpdatedByDeviceId = "transactions.updatedByDeviceId"
    case transactionNextSeq = "transactions.nextSeq"
    case templateNextSeq = "templates.nextSeq"
    case budgetNextSeq = "budgets.nextSeq"
}

private enum SQLiteBinding {
    case text(String)
    case nullableText(String?)
    case int(Int)
    case nullableInt(Int?)
}

private struct SyncOpRow {
    var opId: String
    var schemaVersion: Int
    var ledgerId: String
    var deviceId: String
    var seq: Int
    var entity: String
    var entityId: String
    var action: String
    var occurredAt: Date
    var createdAt: Date
    var payloadJSON: String?
}

private protocol LedgerSortKeyConvertible {
    var occurredAt: Date { get }
    var deviceId: String { get }
    var seq: Int { get }
}

private struct SimpleSortKey: LedgerSortKeyConvertible {
    var occurredAt: Date
    var deviceId: String
    var seq: Int
}

extension MetadataOpSortKey: LedgerSortKeyConvertible {}
extension TransactionOpSortKey: LedgerSortKeyConvertible {}
extension TemplateOpSortKey: LedgerSortKeyConvertible {}
extension BudgetOpSortKey: LedgerSortKeyConvertible {}
