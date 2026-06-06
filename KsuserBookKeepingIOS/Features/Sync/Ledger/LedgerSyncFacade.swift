import Foundation

struct LedgerSyncFacade {
    private let metadataSyncService: BookkeepingMetadataSyncService
    private let transactionsSyncService: BookkeepingTransactionsSyncService
    private let templatesSyncService: BookkeepingTemplatesSyncService
    private let budgetsSyncService: BookkeepingBudgetsSyncService

    init(
        metadataSyncService: BookkeepingMetadataSyncService = BookkeepingMetadataSyncService(),
        transactionsSyncService: BookkeepingTransactionsSyncService = BookkeepingTransactionsSyncService(),
        templatesSyncService: BookkeepingTemplatesSyncService = BookkeepingTemplatesSyncService(),
        budgetsSyncService: BookkeepingBudgetsSyncService = BookkeepingBudgetsSyncService()
    ) {
        self.metadataSyncService = metadataSyncService
        self.transactionsSyncService = transactionsSyncService
        self.templatesSyncService = templatesSyncService
        self.budgetsSyncService = budgetsSyncService
    }

    func backupMetadata(
        ops: [BookkeepingMetadataOp],
        configuration: SyncConfiguration,
        secrets: SyncSecrets
    ) async throws {
        try await metadataSyncService.backup(ops: ops, configuration: configuration, secrets: secrets)
    }

    func importMetadata(
        configuration: SyncConfiguration,
        secrets: SyncSecrets
    ) async throws -> [BookkeepingMetadataOp] {
        try await metadataSyncService.importRemoteOps(configuration: configuration, secrets: secrets)
    }

    func backupTransactions(
        ops: [BookkeepingTransactionOp],
        configuration: SyncConfiguration,
        secrets: SyncSecrets
    ) async throws {
        try await transactionsSyncService.backup(ops: ops, configuration: configuration, secrets: secrets)
    }

    func importTransactions(
        configuration: SyncConfiguration,
        secrets: SyncSecrets
    ) async throws -> [BookkeepingTransactionOp] {
        try await transactionsSyncService.importRemoteOps(configuration: configuration, secrets: secrets)
    }

    func backupTemplates(
        ops: [BookkeepingTemplateOp],
        configuration: SyncConfiguration,
        secrets: SyncSecrets
    ) async throws {
        try await templatesSyncService.backup(ops: ops, configuration: configuration, secrets: secrets)
    }

    func importTemplates(
        configuration: SyncConfiguration,
        secrets: SyncSecrets
    ) async throws -> [BookkeepingTemplateOp] {
        try await templatesSyncService.importRemoteOps(configuration: configuration, secrets: secrets)
    }

    func backupBudgets(
        ops: [BookkeepingBudgetOp],
        configuration: SyncConfiguration,
        secrets: SyncSecrets
    ) async throws {
        try await budgetsSyncService.backup(ops: ops, configuration: configuration, secrets: secrets)
    }

    func importBudgets(
        configuration: SyncConfiguration,
        secrets: SyncSecrets
    ) async throws -> [BookkeepingBudgetOp] {
        try await budgetsSyncService.importRemoteOps(configuration: configuration, secrets: secrets)
    }
}
