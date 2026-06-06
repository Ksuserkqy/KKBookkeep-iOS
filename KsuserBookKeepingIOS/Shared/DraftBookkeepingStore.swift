import Combine
import Foundation
import SwiftUI
#if canImport(WidgetKit)
import WidgetKit
#endif

enum DraftEntryKind: String, CaseIterable, Codable, Identifiable {
    case expense
    case income
    case transfer

    var id: String { rawValue }

    var titleKey: LocalizedStringKey {
        switch self {
        case .expense:
            return LocalizedStringKey(localizationKey)
        case .income:
            return LocalizedStringKey(localizationKey)
        case .transfer:
            return LocalizedStringKey(localizationKey)
        }
    }

    var localizationKey: String {
        switch self {
        case .expense:
            return "record.kind.expense"
        case .income:
            return "record.kind.income"
        case .transfer:
            return "record.kind.transfer"
        }
    }
}

struct DraftAccount: Codable, Identifiable, Equatable {
    var id: String
    var name: String
    var isDefault: Bool
    var type: DraftAccountType
    var iconName: String
    var colorHex: String
    var balanceText: String
    var note: String
    var archivedAt: Date?

    var isArchived: Bool {
        archivedAt != nil
    }

    init(
        id: String,
        name: String,
        isDefault: Bool,
        type: DraftAccountType = .cash,
        iconName: String = "wallet",
        colorHex: String = "#F6C343",
        balanceText: String = "0",
        note: String = "",
        archivedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.isDefault = isDefault
        self.type = type
        self.iconName = iconName
        self.colorHex = colorHex
        self.balanceText = balanceText
        self.note = note
        self.archivedAt = archivedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.name = try container.decode(String.self, forKey: .name)
        self.isDefault = try container.decode(Bool.self, forKey: .isDefault)
        self.type = try container.decodeIfPresent(DraftAccountType.self, forKey: .type) ?? .cash
        self.iconName = try container.decodeIfPresent(String.self, forKey: .iconName) ?? ""
        self.colorHex = try container.decodeIfPresent(String.self, forKey: .colorHex) ?? ""
        self.balanceText = try container.decodeIfPresent(String.self, forKey: .balanceText) ?? "0"
        self.note = try container.decodeIfPresent(String.self, forKey: .note) ?? ""
        self.archivedAt = try container.decodeIfPresent(Date.self, forKey: .archivedAt)
    }
}

struct DraftCategory: Codable, Identifiable, Equatable {
    var id: String
    var name: String
    var isDefault: Bool
    var kind: DraftEntryKind
    var parentId: String?
    var iconName: String
    var colorHex: String
    var archivedAt: Date?

    var isArchived: Bool {
        archivedAt != nil
    }

    init(
        id: String,
        name: String,
        isDefault: Bool = false,
        kind: DraftEntryKind,
        parentId: String? = nil,
        iconName: String = "tag",
        colorHex: String = "#F6C343",
        archivedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.isDefault = isDefault
        self.kind = kind
        self.parentId = parentId
        self.iconName = iconName
        self.colorHex = colorHex
        self.archivedAt = archivedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.name = try container.decode(String.self, forKey: .name)
        self.isDefault = try container.decodeIfPresent(Bool.self, forKey: .isDefault) ?? false
        self.kind = try container.decode(DraftEntryKind.self, forKey: .kind)
        self.parentId = try container.decodeIfPresent(String.self, forKey: .parentId)
        self.iconName = try container.decodeIfPresent(String.self, forKey: .iconName) ?? ""
        self.colorHex = try container.decodeIfPresent(String.self, forKey: .colorHex) ?? ""
        self.archivedAt = try container.decodeIfPresent(Date.self, forKey: .archivedAt)
    }
}

struct DraftCategoryHierarchyItem: Identifiable, Equatable {
    let category: DraftCategory
    let depth: Int

    var id: String {
        category.id
    }
}

enum DraftAccountType: String, CaseIterable, Codable, Identifiable {
    case cash
    case debitCard
    case creditCard
    case savings
    case digitalWallet
    case other

    var id: String { rawValue }

    var titleKey: LocalizedStringKey {
        LocalizedStringKey(localizationKey)
    }

    var localizationKey: String {
        switch self {
        case .cash:
            return "management.account.type.cash"
        case .debitCard:
            return "management.account.type.debitCard"
        case .creditCard:
            return "management.account.type.creditCard"
        case .savings:
            return "management.account.type.savings"
        case .digitalWallet:
            return "management.account.type.digitalWallet"
        case .other:
            return "management.account.type.other"
        }
    }
}

struct DraftTransaction: Codable, Identifiable, Equatable {
    var id: String
    var kind: DraftEntryKind
    var amountText: String
    var transferInAmountText: String?
    var categoryId: String?
    var accountId: String?
    var fromAccountId: String?
    var toAccountId: String?
    var date: Date
    var note: String
    var location: DraftLocation?
    var createdAt: Date
}

struct DraftTransactionTemplate: Codable, Identifiable, Equatable {
    var id: String
    var name: String
    var kind: DraftEntryKind
    var amountText: String
    var categoryId: String
    var accountId: String
    var note: String
    var createdAt: Date
    var updatedAt: Date
}

enum DraftBudgetScope: String, CaseIterable, Codable, Identifiable {
    case overall
    case category
    case account

    var id: String { rawValue }

    var titleKey: LocalizedStringKey {
        LocalizedStringKey(localizationKey)
    }

    var localizationKey: String {
        switch self {
        case .overall:
            return "budgets.scope.overall"
        case .category:
            return "budgets.scope.category"
        case .account:
            return "budgets.scope.account"
        }
    }
}

struct DraftBudget: Codable, Identifiable, Equatable {
    var id: String
    var name: String
    var scope: DraftBudgetScope
    var targetId: String?
    var amountText: String
    var isEnabled: Bool
    var createdAt: Date
    var updatedAt: Date
}

struct DraftBudgetUsage: Identifiable, Equatable {
    var budget: DraftBudget
    var targetName: String
    var spentText: String
    var limitText: String
    var remainingText: String
    var percentUsed: Double
    var isOverLimit: Bool

    var id: String { budget.id }
}

struct DraftLocation: Codable, Equatable {
    var displayName: String
    var address: String
    var latitude: Double
    var longitude: Double
    var horizontalAccuracy: Double
    var capturedAt: Date

    var coordinateText: String {
        String(format: "%.5f, %.5f", latitude, longitude)
    }
}

@MainActor
final class DraftBookkeepingStore: ObservableObject {
    @Published private(set) var accounts: [DraftAccount]
    @Published private(set) var categories: [DraftCategory]
    @Published private(set) var transactions: [DraftTransaction]
    @Published private(set) var transactionTemplates: [DraftTransactionTemplate]
    @Published private(set) var budgets: [DraftBudget]
    @Published private(set) var lastDraft: DraftTransaction?
    @Published private(set) var messageKey: String?
    @Published private(set) var localMetadataChangeToken = 0
    @Published private(set) var localTransactionsChangeToken = 0
    @Published private(set) var localTemplatesChangeToken = 0
    @Published private(set) var localBudgetsChangeToken = 0

    private let sqliteStore: LedgerSQLiteStore
    private let ledgerSyncFacade: LedgerSyncFacade
    private var metadataRevision: Int
    private var metadataUpdatedAt: Date
    private var metadataUpdatedByDeviceId: String
    private var nextMetadataOpSeq: Int
    private var localMetadataOps: [BookkeepingMetadataOp]
    private var uploadedMetadataOpIds: Set<String>
    private var processedMetadataOpIds: Set<String>
    private var importedMetadataSeqByDeviceId: [String: Int]
    private var metadataOpSortKeysById: [String: MetadataOpSortKey]
    private var deletedMetadataOpSortKeysById: [String: MetadataOpSortKey]
    private var transactionsRevision: Int
    private var transactionsUpdatedAt: Date
    private var transactionsUpdatedByDeviceId: String
    private var nextTransactionOpSeq: Int
    private var localTransactionOps: [BookkeepingTransactionOp]
    private var uploadedTransactionOpIds: Set<String>
    private var processedTransactionOpIds: Set<String>
    private var importedTransactionSeqByDeviceId: [String: Int]
    private var transactionOpSortKeysById: [String: TransactionOpSortKey]
    private var deletedTransactionOpSortKeysById: [String: TransactionOpSortKey]
    private var accountBaseBalanceTextById: [String: String]
    private var nextTemplateOpSeq: Int
    private var localTemplateOps: [BookkeepingTemplateOp]
    private var uploadedTemplateOpIds: Set<String>
    private var processedTemplateOpIds: Set<String>
    private var importedTemplateSeqByDeviceId: [String: Int]
    private var templateOpSortKeysById: [String: TemplateOpSortKey]
    private var deletedTemplateOpSortKeysById: [String: TemplateOpSortKey]
    private var nextBudgetOpSeq: Int
    private var localBudgetOps: [BookkeepingBudgetOp]
    private var uploadedBudgetOpIds: Set<String>
    private var processedBudgetOpIds: Set<String>
    private var importedBudgetSeqByDeviceId: [String: Int]
    private var budgetOpSortKeysById: [String: BudgetOpSortKey]
    private var deletedBudgetOpSortKeysById: [String: BudgetOpSortKey]

    private static let maxCategoryDepth = 3

    convenience init() {
        self.init(sqliteStore: .shared, ledgerSyncFacade: LedgerSyncFacade())
    }

    init(
        sqliteStore: LedgerSQLiteStore,
        ledgerSyncFacade: LedgerSyncFacade
    ) {
        self.sqliteStore = sqliteStore
        self.ledgerSyncFacade = ledgerSyncFacade
        let snapshot = Self.initialSnapshot(from: sqliteStore)
        let sortedTransactions = snapshot.transactions.sorted(by: Self.transactionSort)

        self.accounts = snapshot.accounts
        self.categories = snapshot.categories
        self.transactions = sortedTransactions
        self.transactionTemplates = snapshot.transactionTemplates
        self.budgets = snapshot.budgets
        self.lastDraft = snapshot.lastDraft ?? sortedTransactions.first
        self.metadataRevision = snapshot.metadataRevision
        self.metadataUpdatedAt = snapshot.metadataUpdatedAt
        self.metadataUpdatedByDeviceId = snapshot.metadataUpdatedByDeviceId
        self.nextMetadataOpSeq = max(1, snapshot.nextMetadataOpSeq)
        self.localMetadataOps = snapshot.localMetadataOps
        self.uploadedMetadataOpIds = snapshot.uploadedMetadataOpIds
        self.processedMetadataOpIds = snapshot.processedMetadataOpIds
        self.importedMetadataSeqByDeviceId = snapshot.importedMetadataSeqByDeviceId
        self.metadataOpSortKeysById = snapshot.metadataOpSortKeysById
        self.deletedMetadataOpSortKeysById = snapshot.deletedMetadataOpSortKeysById
        self.transactionsRevision = snapshot.transactionsRevision
        self.transactionsUpdatedAt = snapshot.transactionsUpdatedAt
        self.transactionsUpdatedByDeviceId = snapshot.transactionsUpdatedByDeviceId
        self.nextTransactionOpSeq = max(1, snapshot.nextTransactionOpSeq)
        self.localTransactionOps = snapshot.localTransactionOps
        self.uploadedTransactionOpIds = snapshot.uploadedTransactionOpIds
        self.processedTransactionOpIds = snapshot.processedTransactionOpIds
        self.importedTransactionSeqByDeviceId = snapshot.importedTransactionSeqByDeviceId
        self.transactionOpSortKeysById = snapshot.transactionOpSortKeysById
        self.deletedTransactionOpSortKeysById = snapshot.deletedTransactionOpSortKeysById
        self.accountBaseBalanceTextById = snapshot.accountBaseBalanceTextById
        self.nextTemplateOpSeq = max(1, snapshot.nextTemplateOpSeq)
        self.localTemplateOps = snapshot.localTemplateOps
        self.uploadedTemplateOpIds = snapshot.uploadedTemplateOpIds
        self.processedTemplateOpIds = snapshot.processedTemplateOpIds
        self.importedTemplateSeqByDeviceId = snapshot.importedTemplateSeqByDeviceId
        self.templateOpSortKeysById = snapshot.templateOpSortKeysById
        self.deletedTemplateOpSortKeysById = snapshot.deletedTemplateOpSortKeysById
        self.nextBudgetOpSeq = max(1, snapshot.nextBudgetOpSeq)
        self.localBudgetOps = snapshot.localBudgetOps
        self.uploadedBudgetOpIds = snapshot.uploadedBudgetOpIds
        self.processedBudgetOpIds = snapshot.processedBudgetOpIds
        self.importedBudgetSeqByDeviceId = snapshot.importedBudgetSeqByDeviceId
        self.budgetOpSortKeysById = snapshot.budgetOpSortKeysById
        self.deletedBudgetOpSortKeysById = snapshot.deletedBudgetOpSortKeysById

        normalizeDefaultNames()
        normalizeCategoryHierarchy()
        normalizeDefaultSelections()
        normalizeTransactionsAfterMetadataChange()
        normalizeTransactionTemplates()
        normalizeBudgets()
        initializeTemplateSyncStateIfNeeded()
        initializeBudgetSyncStateIfNeeded()
        initializeTransactionSyncStateIfNeeded()
        recomputeAccountBalancesFromBase()
        persistLedgerSnapshot()
        persistWidgetSnapshot()
    }

    private static func initialSnapshot(from sqliteStore: LedgerSQLiteStore) -> LedgerSnapshot {
        guard var snapshot = sqliteStore.loadLedgerSnapshot() else {
            return LedgerSnapshot(accounts: defaultAccounts, categories: defaultCategories)
        }

        let hasLedgerData = !snapshot.accounts.isEmpty
            || !snapshot.categories.isEmpty
            || !snapshot.transactions.isEmpty
            || !snapshot.transactionTemplates.isEmpty
            || !snapshot.budgets.isEmpty
            || snapshot.lastDraft != nil
            || !snapshot.localMetadataOps.isEmpty
            || !snapshot.localTransactionOps.isEmpty
            || !snapshot.localTemplateOps.isEmpty
            || !snapshot.localBudgetOps.isEmpty
            || !snapshot.processedMetadataOpIds.isEmpty
            || !snapshot.processedTransactionOpIds.isEmpty
            || !snapshot.processedTemplateOpIds.isEmpty
            || !snapshot.processedBudgetOpIds.isEmpty
            || !snapshot.importedMetadataSeqByDeviceId.isEmpty
            || !snapshot.importedTransactionSeqByDeviceId.isEmpty
            || !snapshot.importedTemplateSeqByDeviceId.isEmpty
            || !snapshot.importedBudgetSeqByDeviceId.isEmpty

        if !hasLedgerData {
            snapshot.accounts = defaultAccounts
            snapshot.categories = defaultCategories
            snapshot.accountBaseBalanceTextById = Dictionary(
                uniqueKeysWithValues: defaultAccounts.map { ($0.id, normalizedBalanceText($0.balanceText)) }
            )
        }

        return snapshot
    }

    func clearMessage() {
        messageKey = nil
    }

    func categories(for kind: DraftEntryKind) -> [DraftCategory] {
        categories.filter { $0.kind == kind && !$0.isArchived }
    }

    func categoryHierarchyItems(for kind: DraftEntryKind) -> [DraftCategoryHierarchyItem] {
        categories
            .filter { $0.kind == kind && $0.parentId == nil && !$0.isArchived }
            .flatMap { hierarchyItems(from: $0, depth: 1, visitedIds: []) }
    }

    func childCategories(of id: String) -> [DraftCategory] {
        categories.filter { $0.parentId == id && !$0.isArchived }
    }

    func hasChildCategories(id: String) -> Bool {
        categories.contains { $0.parentId == id }
    }

    func selectableParentItems(for kind: DraftEntryKind, excluding categoryId: String?) -> [DraftCategoryHierarchyItem] {
        categoryHierarchyItems(for: kind).filter { item in
            canUseParent(item.category.id, for: categoryId, kind: kind)
        }
    }

    func canUseParent(_ parentId: String?, for categoryId: String?, kind: DraftEntryKind) -> Bool {
        guard let parentId else {
            return true
        }

        guard let parent = categories.first(where: { $0.id == parentId }) else {
            return false
        }
        guard parent.kind == kind else {
            return false
        }
        guard parent.id != categoryId else {
            return false
        }

        let parentDepth = categoryDepth(for: parent.id)
        guard parentDepth < Self.maxCategoryDepth else {
            return false
        }

        if let categoryId {
            guard !categoryDescendantIds(for: categoryId).contains(parent.id) else {
                return false
            }

            let targetDepth = parentDepth + 1
            let deepestMovedDepth = targetDepth + maxRelativeDescendantDepth(from: categoryId) - 1
            return deepestMovedDepth <= Self.maxCategoryDepth
        }

        return true
    }

    func accountName(for id: String?) -> String {
        guard
            let id,
            let account = accounts.first(where: { $0.id == id })
        else {
            return NSLocalizedString("draft.item.missing", comment: "")
        }

        return account.name
    }

    func categoryName(for id: String?) -> String {
        categoryDisplayName(for: id)
    }

    func categoryDisplayName(for id: String?) -> String {
        guard
            let id,
            categories.contains(where: { $0.id == id })
        else {
            return NSLocalizedString("draft.item.missing", comment: "")
        }

        return categoryPath(for: id).map(\.name).joined(separator: " / ")
    }

    func accountBalanceSummary(for id: String?) -> String {
        guard
            let id,
            let account = accounts.first(where: { $0.id == id })
        else {
            return NSLocalizedString("draft.item.missing", comment: "")
        }

        return String(
            format: NSLocalizedString("selection.account.balanceFormat", comment: ""),
            DraftAmountFormatter.currencyText(from: account.balanceText)
        )
    }

    func categoryTodaySummary(for id: String?, calendar: Calendar = .current, now: Date = Date()) -> String {
        guard let id else {
            return NSLocalizedString("draft.item.missing", comment: "")
        }

        let startOfDay = calendar.startOfDay(for: now)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            return NSLocalizedString("draft.item.missing", comment: "")
        }

        let todayTransactions = transactions.filter { transaction in
            transaction.categoryId == id &&
            transaction.date >= startOfDay &&
            transaction.date < endOfDay
        }

        let income = todayTransactions.reduce(Decimal(0)) { partialResult, transaction in
            transaction.kind == .income ? partialResult + decimalValue(from: transaction.amountText) : partialResult
        }
        let expense = todayTransactions.reduce(Decimal(0)) { partialResult, transaction in
            transaction.kind == .expense ? partialResult + decimalValue(from: transaction.amountText) : partialResult
        }

        return String(
            format: NSLocalizedString("selection.category.todayFormat", comment: ""),
            DraftAmountFormatter.currencyText(from: Self.plainAmountText(from: income)),
            DraftAmountFormatter.currencyText(from: Self.plainAmountText(from: expense))
        )
    }

    func budgetDisplayName(_ budget: DraftBudget) -> String {
        guard budget.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return budget.name
        }

        switch budget.scope {
        case .overall:
            return NSLocalizedString("budgets.defaultName.overall", comment: "")
        case .category:
            return categoryDisplayName(for: budget.targetId)
        case .account:
            return accountName(for: budget.targetId)
        }
    }

    func budgetTargetName(_ budget: DraftBudget) -> String {
        switch budget.scope {
        case .overall:
            return NSLocalizedString("budgets.scope.overall", comment: "")
        case .category:
            return categoryDisplayName(for: budget.targetId)
        case .account:
            return accountName(for: budget.targetId)
        }
    }

    func budgetUsages(now: Date = Date(), calendar: Calendar = .current) -> [DraftBudgetUsage] {
        budgets
            .filter(\.isEnabled)
            .sorted(by: Self.budgetSort)
            .map { budgetUsage(for: $0, now: now, calendar: calendar) }
    }

    func budgetUsage(for budget: DraftBudget, now: Date = Date(), calendar: Calendar = .current) -> DraftBudgetUsage {
        let spent = monthlyExpense(for: budget, now: now, calendar: calendar)
        let limit = decimalValue(from: budget.amountText)
        let remaining = limit - spent
        let percentUsed: Double
        if limit > 0 {
            percentUsed = min(Self.doubleValue(from: spent) / Self.doubleValue(from: limit), 9.99)
        } else {
            percentUsed = 0
        }

        return DraftBudgetUsage(
            budget: budget,
            targetName: budgetTargetName(budget),
            spentText: Self.plainAmountText(from: spent),
            limitText: budget.amountText,
            remainingText: Self.plainAmountText(from: remaining),
            percentUsed: percentUsed,
            isOverLimit: spent > limit
        )
    }

    func budgetUsageForRecentExpense(
        _ transaction: DraftTransaction,
        preferredBudgetId: String?,
        now: Date? = nil,
        calendar: Calendar = .current
    ) -> DraftBudgetUsage? {
        guard transaction.kind == .expense else { return nil }

        let referenceDate = now ?? transaction.date
        let enabledUsages = budgetUsages(now: referenceDate, calendar: calendar)
        if
            let preferredBudgetId,
            let usage = enabledUsages.first(where: { $0.budget.id == preferredBudgetId })
        {
            return usage
        }

        return enabledUsages.first { usage in
            budgetIncludes(usage.budget, transaction: transaction)
        }
    }

    @discardableResult
    func addBudget(name: String, scope: DraftBudgetScope, targetId: String?, amountText: String, isEnabled: Bool) -> Bool {
        guard let normalizedBudget = makeBudget(
            id: UUID().uuidString,
            existingCreatedAt: nil,
            name: name,
            scope: scope,
            targetId: targetId,
            amountText: amountText,
            isEnabled: isEnabled
        ) else {
            return false
        }

        initializeBudgetSyncStateIfNeeded()
        budgets.insert(normalizedBudget, at: 0)
        budgets.sort(by: Self.budgetSort)
        persistBudgets()
        appendLocalBudgetOp(action: .create, budget: normalizedBudget, occurredAt: normalizedBudget.createdAt)
        messageKey = "budgets.message.saved"
        return true
    }

    @discardableResult
    func updateBudget(id: String, name: String, scope: DraftBudgetScope, targetId: String?, amountText: String, isEnabled: Bool) -> Bool {
        guard let index = budgets.firstIndex(where: { $0.id == id }) else { return false }
        guard let normalizedBudget = makeBudget(
            id: id,
            existingCreatedAt: budgets[index].createdAt,
            name: name,
            scope: scope,
            targetId: targetId,
            amountText: amountText,
            isEnabled: isEnabled
        ) else {
            return false
        }

        initializeBudgetSyncStateIfNeeded()
        budgets[index] = normalizedBudget
        budgets.sort(by: Self.budgetSort)
        persistBudgets()
        appendLocalBudgetOp(action: .update, budget: normalizedBudget)
        messageKey = "budgets.message.saved"
        return true
    }

    @discardableResult
    func deleteBudget(id: String) -> Bool {
        guard let index = budgets.firstIndex(where: { $0.id == id }) else { return false }

        initializeBudgetSyncStateIfNeeded()
        let budget = budgets.remove(at: index)
        persistBudgets()
        appendLocalBudgetOp(action: .delete, budget: budget)
        messageKey = "budgets.message.deleted"
        return true
    }

    func saveTransaction(_ transaction: DraftTransaction) {
        let normalizedTransaction = normalizedTransactionAmounts(transaction)
        transactions.insert(normalizedTransaction, at: 0)
        transactions.sort(by: Self.transactionSort)
        lastDraft = transactions.first
        applyTransactionToAccountBalances(normalizedTransaction)
        persistAccounts()
        persistTransactions()
        persistLastDraft()
        appendLocalTransactionOp(action: .create, transaction: normalizedTransaction, occurredAt: normalizedTransaction.createdAt)
        persistWidgetSnapshot()
        messageKey = "record.transaction.saved"
    }

    @discardableResult
    func updateTransaction(_ transaction: DraftTransaction) -> Bool {
        guard let index = transactions.firstIndex(where: { $0.id == transaction.id }) else { return false }

        let normalizedTransaction = normalizedTransactionAmounts(transaction)
        let originalTransaction = transactions[index]
        applyTransactionToAccountBalances(originalTransaction, multiplier: -1)
        transactions[index] = normalizedTransaction
        transactions.sort(by: Self.transactionSort)
        lastDraft = transactions.first
        applyTransactionToAccountBalances(normalizedTransaction)
        persistAccounts()
        persistTransactions()
        persistLastDraft()
        appendLocalTransactionOp(action: .update, transaction: normalizedTransaction)
        persistWidgetSnapshot()
        messageKey = "transactions.message.updated"
        return true
    }

    @discardableResult
    func deleteTransaction(id: String) -> Bool {
        guard let index = transactions.firstIndex(where: { $0.id == id }) else { return false }

        let transaction = transactions.remove(at: index)
        applyTransactionToAccountBalances(transaction, multiplier: -1)
        lastDraft = transactions.first
        persistAccounts()
        persistTransactions()
        persistLastDraft()
        appendLocalTransactionOp(action: .delete, transaction: transaction)
        persistWidgetSnapshot()
        messageKey = "transactions.message.deleted"
        return true
    }

    @discardableResult
    func addTransactionTemplate(
        name: String,
        kind: DraftEntryKind,
        amountText: String,
        categoryId: String,
        accountId: String,
        note: String
    ) -> Bool {
        guard kind != .transfer else { return false }

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return false }
        guard let normalizedAmountText = Self.normalizedPositiveAmountText(amountText) else { return false }
        guard isActiveCategory(id: categoryId, kind: kind), isActiveAccount(id: accountId) else { return false }

        let now = Date()
        let template = DraftTransactionTemplate(
            id: UUID().uuidString,
            name: trimmedName,
            kind: kind,
            amountText: normalizedAmountText,
            categoryId: categoryId,
            accountId: accountId,
            note: trimmedNote,
            createdAt: now,
            updatedAt: now
        )

        initializeTemplateSyncStateIfNeeded()
        transactionTemplates.insert(template, at: 0)
        persistTransactionTemplates()
        appendLocalTemplateOp(action: .create, template: template, occurredAt: template.createdAt)
        messageKey = "templates.message.saved"
        return true
    }

    @discardableResult
    func updateTransactionTemplate(
        id: String,
        name: String,
        kind: DraftEntryKind,
        amountText: String,
        categoryId: String,
        accountId: String,
        note: String
    ) -> Bool {
        guard kind != .transfer else { return false }
        guard let index = transactionTemplates.firstIndex(where: { $0.id == id }) else { return false }

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return false }
        guard let normalizedAmountText = Self.normalizedPositiveAmountText(amountText) else { return false }
        guard isActiveCategory(id: categoryId, kind: kind), isActiveAccount(id: accountId) else { return false }

        initializeTemplateSyncStateIfNeeded()
        let updatedTemplate = DraftTransactionTemplate(
            id: id,
            name: trimmedName,
            kind: kind,
            amountText: normalizedAmountText,
            categoryId: categoryId,
            accountId: accountId,
            note: trimmedNote,
            createdAt: transactionTemplates[index].createdAt,
            updatedAt: Date()
        )
        transactionTemplates[index] = updatedTemplate
        transactionTemplates.sort(by: Self.transactionTemplateSort)
        persistTransactionTemplates()
        appendLocalTemplateOp(action: .update, template: updatedTemplate)
        messageKey = "templates.message.saved"
        return true
    }

    @discardableResult
    func deleteTransactionTemplate(id: String) -> Bool {
        guard let index = transactionTemplates.firstIndex(where: { $0.id == id }) else { return false }

        initializeTemplateSyncStateIfNeeded()
        let template = transactionTemplates.remove(at: index)
        persistTransactionTemplates()
        appendLocalTemplateOp(action: .delete, template: template)
        messageKey = "templates.message.deleted"
        return true
    }

    func backupLedgerDataNow(
        configuration: SyncConfiguration,
        secrets: SyncSecrets,
        forceFullUpload: Bool = false
    ) async -> Bool {
        guard configuration.backupEnabled else {
            messageKey = "bookkeeping.ledger.sync.error.backupDisabled"
            return false
        }

        do {
            try await backupPendingMetadataOps(configuration: configuration, secrets: secrets, forceFullUpload: forceFullUpload)
            try await backupPendingTransactionOps(configuration: configuration, secrets: secrets, forceFullUpload: forceFullUpload)
            try await backupPendingTemplateOps(configuration: configuration, secrets: secrets, forceFullUpload: forceFullUpload)
            try await backupPendingBudgetOps(configuration: configuration, secrets: secrets, forceFullUpload: forceFullUpload)
            messageKey = "bookkeeping.ledger.sync.backupSucceeded"
            return true
        } catch {
            messageKey = "bookkeeping.ledger.sync.error.backupFailed"
            return false
        }
    }

    @discardableResult
    func importRemoteLedgerDataBeforeBackup(configuration: SyncConfiguration, secrets: SyncSecrets) async -> Bool {
        guard configuration.backupEnabled else {
            messageKey = "bookkeeping.ledger.sync.error.backupDisabled"
            return false
        }

        do {
            _ = try await importMetadataOps(configuration: configuration, secrets: secrets)
            _ = try await importTransactionOps(configuration: configuration, secrets: secrets)
            _ = try await importTemplateOps(configuration: configuration, secrets: secrets)
            _ = try await importBudgetOps(configuration: configuration, secrets: secrets)
            return true
        } catch {
            messageKey = "bookkeeping.ledger.sync.error.importFailed"
            return false
        }
    }

    func backupMetadataNow(configuration: SyncConfiguration, secrets: SyncSecrets) async -> Bool {
        guard configuration.backupEnabled else {
            messageKey = "bookkeeping.metadata.sync.error.backupDisabled"
            return false
        }

        do {
            try await backupPendingMetadataOps(configuration: configuration, secrets: secrets)
            messageKey = "bookkeeping.metadata.sync.backupSucceeded"
            return true
        } catch {
            messageKey = "bookkeeping.metadata.sync.error.backupFailed"
            return false
        }
    }

    func importMetadataNow(configuration: SyncConfiguration, secrets: SyncSecrets) async -> Bool {
        guard configuration.backupEnabled else {
            messageKey = "bookkeeping.metadata.sync.error.backupDisabled"
            return false
        }

        do {
            let didImport = try await importMetadataOps(configuration: configuration, secrets: secrets)
            messageKey = didImport ? "bookkeeping.metadata.sync.importSucceeded" : "bookkeeping.metadata.sync.importNoRemoteMetadata"
            return true
        } catch {
            messageKey = "bookkeeping.metadata.sync.error.importFailed"
            return false
        }
    }

    func backupTransactionsNow(configuration: SyncConfiguration, secrets: SyncSecrets) async -> Bool {
        guard configuration.backupEnabled else {
            messageKey = "bookkeeping.transactions.sync.error.backupDisabled"
            return false
        }

        do {
            try await backupPendingTransactionOps(configuration: configuration, secrets: secrets)
            messageKey = "bookkeeping.transactions.sync.backupSucceeded"
            return true
        } catch {
            messageKey = "bookkeeping.transactions.sync.error.backupFailed"
            return false
        }
    }

    func importTransactionsNow(configuration: SyncConfiguration, secrets: SyncSecrets) async -> Bool {
        guard configuration.backupEnabled else {
            messageKey = "bookkeeping.transactions.sync.error.backupDisabled"
            return false
        }

        do {
            let didImport = try await importTransactionOps(configuration: configuration, secrets: secrets)
            messageKey = didImport ? "bookkeeping.transactions.sync.importSucceeded" : "bookkeeping.transactions.sync.importNoRemoteTransactions"
            return true
        } catch {
            messageKey = "bookkeeping.transactions.sync.error.importFailed"
            return false
        }
    }

    func backupTemplatesNow(configuration: SyncConfiguration, secrets: SyncSecrets) async -> Bool {
        guard configuration.backupEnabled else {
            messageKey = "bookkeeping.templates.sync.error.backupDisabled"
            return false
        }

        do {
            try await backupPendingTemplateOps(configuration: configuration, secrets: secrets)
            messageKey = "bookkeeping.templates.sync.backupSucceeded"
            return true
        } catch {
            messageKey = "bookkeeping.templates.sync.error.backupFailed"
            return false
        }
    }

    func importTemplatesNow(configuration: SyncConfiguration, secrets: SyncSecrets) async -> Bool {
        guard configuration.backupEnabled else {
            messageKey = "bookkeeping.templates.sync.error.backupDisabled"
            return false
        }

        do {
            let didImport = try await importTemplateOps(configuration: configuration, secrets: secrets)
            messageKey = didImport ? "bookkeeping.templates.sync.importSucceeded" : "bookkeeping.templates.sync.importNoRemoteTemplates"
            return true
        } catch {
            messageKey = "bookkeeping.templates.sync.error.importFailed"
            return false
        }
    }

    func backupBudgetsNow(configuration: SyncConfiguration, secrets: SyncSecrets) async -> Bool {
        guard configuration.backupEnabled else {
            messageKey = "bookkeeping.budgets.sync.error.backupDisabled"
            return false
        }

        do {
            try await backupPendingBudgetOps(configuration: configuration, secrets: secrets)
            messageKey = "bookkeeping.budgets.sync.backupSucceeded"
            return true
        } catch {
            messageKey = "bookkeeping.budgets.sync.error.backupFailed"
            return false
        }
    }

    func importBudgetsNow(configuration: SyncConfiguration, secrets: SyncSecrets) async -> Bool {
        guard configuration.backupEnabled else {
            messageKey = "bookkeeping.budgets.sync.error.backupDisabled"
            return false
        }

        do {
            let didImport = try await importBudgetOps(configuration: configuration, secrets: secrets)
            messageKey = didImport ? "bookkeeping.budgets.sync.importSucceeded" : "bookkeeping.budgets.sync.importNoRemoteBudgets"
            return true
        } catch {
            messageKey = "bookkeeping.budgets.sync.error.importFailed"
            return false
        }
    }

    @discardableResult
    func importIfRemoteTransactionsAreNewer(configuration: SyncConfiguration, secrets: SyncSecrets) async -> Bool {
        guard configuration.backupEnabled else { return true }

        do {
            let didImport = try await importTransactionOps(configuration: configuration, secrets: secrets)
            if didImport {
                messageKey = "bookkeeping.transactions.sync.importSucceeded"
            }
            return true
        } catch {
            messageKey = "bookkeeping.transactions.sync.error.importFailed"
            return false
        }
    }

    @discardableResult
    func importIfRemoteTemplatesAreNewer(configuration: SyncConfiguration, secrets: SyncSecrets) async -> Bool {
        guard configuration.backupEnabled else { return true }

        do {
            let didImport = try await importTemplateOps(configuration: configuration, secrets: secrets)
            if didImport {
                messageKey = "bookkeeping.templates.sync.importSucceeded"
            }
            return true
        } catch {
            messageKey = "bookkeeping.templates.sync.error.importFailed"
            return false
        }
    }

    @discardableResult
    func importIfRemoteBudgetsAreNewer(configuration: SyncConfiguration, secrets: SyncSecrets) async -> Bool {
        guard configuration.backupEnabled else { return true }

        do {
            let didImport = try await importBudgetOps(configuration: configuration, secrets: secrets)
            if didImport {
                messageKey = "bookkeeping.budgets.sync.importSucceeded"
            }
            return true
        } catch {
            messageKey = "bookkeeping.budgets.sync.error.importFailed"
            return false
        }
    }

    @discardableResult
    func importIfRemoteMetadataIsNewer(configuration: SyncConfiguration, secrets: SyncSecrets) async -> Bool {
        guard configuration.backupEnabled else { return true }

        do {
            let didImport = try await importMetadataOps(configuration: configuration, secrets: secrets)
            if didImport {
                messageKey = "bookkeeping.metadata.sync.importSucceeded"
            }
            return true
        } catch {
            messageKey = "bookkeeping.metadata.sync.error.importFailed"
            return false
        }
    }

    func addAccount(name: String, type: DraftAccountType, iconName: String, colorHex: String, balanceText: String, note: String) -> Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return false }
        guard let normalizedBalanceText = DraftAmountFormatter.normalizedAmountText(balanceText, allowNegative: false) else {
            messageKey = "management.account.error.invalidBalance"
            return false
        }

        initializeMetadataSyncStateIfNeeded()
        let account = DraftAccount(
            id: UUID().uuidString,
            name: trimmedName,
            isDefault: false,
            type: type,
            iconName: iconName,
            colorHex: colorHex,
            balanceText: normalizedBalanceText,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        accounts.append(account)
        accountBaseBalanceTextById[account.id] = normalizedBalanceText
        persistAccounts()
        persistTransactionSyncState()
        appendLocalMetadataOp(entity: .account, action: .create, account: account, category: nil)
        persistWidgetSnapshot()
        messageKey = "management.account.saved"
        return true
    }

    func updateAccount(id: String, name: String, type: DraftAccountType, iconName: String, colorHex: String, balanceText: String, note: String) -> Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return false }
        guard let normalizedBalanceText = DraftAmountFormatter.normalizedAmountText(balanceText, allowNegative: false) else {
            messageKey = "management.account.error.invalidBalance"
            return false
        }

        guard let index = accounts.firstIndex(where: { $0.id == id }) else { return false }
        initializeMetadataSyncStateIfNeeded()
        accountBaseBalanceTextById[id] = Self.plainAmountText(from: decimalValue(from: normalizedBalanceText) - transactionBalanceDelta(forAccountId: id))
        accounts[index].name = trimmedName
        accounts[index].type = type
        accounts[index].iconName = iconName
        accounts[index].colorHex = colorHex
        accounts[index].balanceText = normalizedBalanceText
        accounts[index].note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        recomputeAccountBalancesFromBase()
        persistAccounts()
        persistTransactionSyncState()
        appendLocalMetadataOp(entity: .account, action: .update, account: accounts[index], category: nil)
        persistWidgetSnapshot()
        messageKey = "management.account.saved"
        return true
    }

    func moveAccounts(from source: IndexSet, to destination: Int) {
        initializeMetadataSyncStateIfNeeded()
        accounts.move(fromOffsets: source, toOffset: destination)
        persistAccounts()
        appendLocalMetadataSnapshotOps(for: .account)
        persistWidgetSnapshot()
    }

    func setDefaultAccount(id: String) {
        guard accounts.contains(where: { $0.id == id && !$0.isArchived }) else { return }

        initializeMetadataSyncStateIfNeeded()
        accounts = accounts.map { account in
            var updated = account
            updated.isDefault = !account.isArchived && account.id == id
            return updated
        }
        persistAccounts()
        appendLocalMetadataSnapshotOps(for: .account)
        persistWidgetSnapshot()
        messageKey = "management.account.defaultSet"
    }

    func deleteAccount(id: String) -> Bool {
        let activeAccounts = accounts.filter { !$0.isArchived }
        guard activeAccounts.count > 1 else {
            messageKey = "management.account.error.lastItem"
            return false
        }

        initializeMetadataSyncStateIfNeeded()
        let opAccount: DraftAccount?
        let opAction: BookkeepingMetadataOpAction
        if isAccountReferenced(id: id), let index = accounts.firstIndex(where: { $0.id == id }) {
            accounts[index].archivedAt = Date()
            accounts[index].isDefault = false
            messageKey = "management.account.archived"
            opAccount = accounts[index]
            opAction = .archive
        } else {
            opAccount = accounts.first(where: { $0.id == id })
            accounts.removeAll { $0.id == id }
            accountBaseBalanceTextById.removeValue(forKey: id)
            messageKey = "management.account.deleted"
            opAction = .delete
        }
        normalizeDefaultAccounts()
        persistAccounts()
        persistTransactionSyncState()
        if opAction == .delete {
            appendLocalMetadataOp(entity: .account, entityId: id, action: .delete, account: nil, category: nil)
        } else if let opAccount {
            appendLocalMetadataOp(entity: .account, action: .archive, account: opAccount, category: nil)
        }
        normalizeBudgets()
        persistBudgets()
        persistWidgetSnapshot()
        return true
    }

    @discardableResult
    func addCategory(name: String, kind: DraftEntryKind, parentId: String?, iconName: String, colorHex: String) -> Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return false }
        guard canUseParent(parentId, for: nil, kind: kind) else {
            messageKey = "management.category.error.invalidParent"
            return false
        }

        initializeMetadataSyncStateIfNeeded()
        let category = DraftCategory(
            id: UUID().uuidString,
            name: trimmedName,
            kind: kind,
            parentId: parentId,
            iconName: iconName,
            colorHex: colorHex
        )
        categories.append(category)
        persistCategories()
        appendLocalMetadataOp(entity: .category, action: .create, account: nil, category: category)
        persistWidgetSnapshot()
        messageKey = "management.category.saved"
        return true
    }

    @discardableResult
    func updateCategory(id: String, name: String, parentId: String?, iconName: String, colorHex: String) -> Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return false }

        guard let index = categories.firstIndex(where: { $0.id == id }) else { return false }
        let kind = categories[index].kind
        guard canUseParent(parentId, for: id, kind: kind) else {
            messageKey = "management.category.error.invalidParent"
            return false
        }
        initializeMetadataSyncStateIfNeeded()
        categories[index].name = trimmedName
        categories[index].parentId = parentId
        if parentId != nil {
            categories[index].isDefault = false
        }
        categories[index].iconName = iconName
        categories[index].colorHex = colorHex
        normalizeDefaultCategories(kind: kind)
        persistCategories()
        appendLocalMetadataOp(entity: .category, action: .update, account: nil, category: categories[index])
        persistWidgetSnapshot()
        messageKey = "management.category.saved"
        return true
    }

    func moveCategories(kind: DraftEntryKind, from source: IndexSet, to destination: Int) {
        initializeMetadataSyncStateIfNeeded()
        let visibleCategories = categoryHierarchyItems(for: kind).map(\.category)
        let movedCategories = source.compactMap { index in
            visibleCategories.indices.contains(index) ? visibleCategories[index] : nil
        }
        guard let firstMovedCategory = movedCategories.first else { return }
        let parentId = firstMovedCategory.parentId
        guard movedCategories.allSatisfy({ $0.parentId == parentId }) else { return }

        var reorderedVisibleCategories = visibleCategories
        reorderedVisibleCategories.move(fromOffsets: source, toOffset: destination)

        let reorderedSiblingIds = reorderedVisibleCategories
            .filter { $0.kind == kind && $0.parentId == parentId }
            .map(\.id)
        let categoriesById = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0) })
        var reorderedSiblingIndex = reorderedSiblingIds.startIndex

        categories = categories.map { category in
            guard category.kind == kind, category.parentId == parentId else {
                return category
            }
            guard reorderedSiblingIndex < reorderedSiblingIds.endIndex else {
                return category
            }

            let reorderedId = reorderedSiblingIds[reorderedSiblingIndex]
            reorderedSiblingIndex = reorderedSiblingIds.index(after: reorderedSiblingIndex)
            return categoriesById[reorderedId] ?? category
        }
        persistCategories()
        appendLocalMetadataSnapshotOps(for: .category)
        persistWidgetSnapshot()
    }

    func setDefaultCategory(id: String) {
        guard let selectedCategory = categories.first(where: { $0.id == id }) else { return }
        guard selectedCategory.parentId == nil else { return }

        initializeMetadataSyncStateIfNeeded()
        categories = categories.map { category in
            var updated = category
            if category.kind == selectedCategory.kind {
                updated.isDefault = category.parentId == nil && category.id == id
            }
            return updated
        }
        persistCategories()
        appendLocalMetadataSnapshotOps(for: .category)
        persistWidgetSnapshot()
        messageKey = "management.category.defaultSet"
    }

    func deleteCategory(id: String) -> Bool {
        guard let category = categories.first(where: { $0.id == id }) else { return false }
        let deletedIds = categoryDescendantIds(for: id).union([id])
        let remainingRootCount = categories.filter { item in
            item.kind == category.kind && item.parentId == nil && !item.isArchived && !deletedIds.contains(item.id)
        }.count

        guard remainingRootCount > 0 else {
            messageKey = "management.category.error.lastItem"
            return false
        }

        initializeMetadataSyncStateIfNeeded()
        let opCategories: [DraftCategory]
        let opAction: BookkeepingMetadataOpAction
        if isAnyCategoryReferenced(ids: deletedIds) {
            categories = categories.map { item in
                var updated = item
                if deletedIds.contains(item.id) {
                    updated.archivedAt = Date()
                    updated.isDefault = false
                }
                return updated
            }
            messageKey = "management.category.archived"
            opCategories = categories.filter { deletedIds.contains($0.id) }
            opAction = .archive
        } else {
            opCategories = categories.filter { deletedIds.contains($0.id) }
            categories.removeAll { deletedIds.contains($0.id) }
            messageKey = "management.category.deleted"
            opAction = .delete
        }
        normalizeDefaultCategories(kind: category.kind)
        persistCategories()
        if opAction == .delete {
            for categoryId in deletedIds {
                appendLocalMetadataOp(entity: .category, entityId: categoryId, action: .delete, account: nil, category: nil)
            }
        } else {
            for opCategory in opCategories {
                appendLocalMetadataOp(entity: .category, action: .archive, account: nil, category: opCategory)
            }
        }
        normalizeBudgets()
        persistBudgets()
        persistWidgetSnapshot()
        return true
    }

    private func isAccountReferenced(id: String) -> Bool {
        transactions.contains { transaction in
            transaction.accountId == id ||
            transaction.fromAccountId == id ||
            transaction.toAccountId == id
        }
    }

    private func isAnyCategoryReferenced(ids: Set<String>) -> Bool {
        transactions.contains { transaction in
            guard let categoryId = transaction.categoryId else { return false }
            return ids.contains(categoryId)
        }
    }

    private func backupPendingMetadataOps(
        configuration: SyncConfiguration,
        secrets: SyncSecrets,
        forceFullUpload: Bool = false
    ) async throws {
        initializeMetadataSyncStateIfNeeded()
        let uploadCandidates = sqliteStore.pendingMetadataOps(forceFullUpload: forceFullUpload)
        guard !uploadCandidates.isEmpty else { return }

        let pendingFileIndexes = Set(uploadCandidates.map(\.fileIndex))
        let opsToWrite = sqliteStore.metadataOps(fileIndexes: pendingFileIndexes)
        try await ledgerSyncFacade.backupMetadata(
            ops: opsToWrite,
            configuration: configuration,
            secrets: secrets
        )
        uploadedMetadataOpIds.formUnion(opsToWrite.map(\.opId))
        sqliteStore.markOpsUploaded(domain: .metadata, opIds: opsToWrite.map(\.opId))
        persistMetadataSyncState()
    }

    @discardableResult
    private func importMetadataOps(
        configuration: SyncConfiguration,
        secrets: SyncSecrets
    ) async throws -> Bool {
        let remoteOps = try await ledgerSyncFacade.importMetadata(
            configuration: configuration,
            secrets: secrets
        )
        let unappliedOps = remoteOps
            .filter { !processedMetadataOpIds.contains($0.opId) }
            .sorted(by: LedgerOpReplayer.replaySort)

        guard !unappliedOps.isEmpty else {
            return false
        }

        for op in unappliedOps {
            applyRemoteMetadataOp(op)
        }

        normalizeDefaultNames()
        normalizeCategoryHierarchy()
        normalizeDefaultSelections()
        normalizeBudgets()
        initializeMissingBaseBalances()
        recomputeAccountBalancesFromBase()
        persistAccounts()
        persistCategories()
        persistBudgets()
        persistMetadata()
        persistMetadataSyncState()
        persistTransactionSyncState()
        persistWidgetSnapshot()
        return true
    }

    private func appendLocalMetadataSnapshotOps(for entity: BookkeepingMetadataEntity) {
        switch entity {
        case .account:
            for account in accounts {
                appendLocalMetadataOp(entity: .account, action: .update, account: account, category: nil)
            }
        case .category:
            for category in categories {
                appendLocalMetadataOp(entity: .category, action: .update, account: nil, category: category)
            }
        }
    }

    private func metadataAccountPayload(_ account: DraftAccount) -> DraftAccount {
        var payload = account
        payload.balanceText = accountBaseBalanceTextById[account.id] ?? account.balanceText
        return payload
    }

    private func appendLocalMetadataOp(
        entity: BookkeepingMetadataEntity,
        entityId: String? = nil,
        action: BookkeepingMetadataOpAction,
        account: DraftAccount?,
        category: DraftCategory?
    ) {
        let resolvedEntityId: String
        switch entity {
        case .account:
            resolvedEntityId = entityId ?? account?.id ?? ""
        case .category:
            resolvedEntityId = entityId ?? category?.id ?? ""
        }
        guard !resolvedEntityId.isEmpty else { return }

        let payload: BookkeepingMetadataOpPayload?
        if action == .delete {
            payload = nil
        } else {
            payload = BookkeepingMetadataOpPayload(account: account.map(metadataAccountPayload), category: category)
        }
        let op = BookkeepingMetadataOp(
            deviceId: DeviceIdentity.currentDeviceId,
            seq: nextMetadataOpSeq,
            entity: entity,
            entityId: resolvedEntityId,
            action: action,
            payload: payload
        )
        nextMetadataOpSeq += 1
        localMetadataOps.append(op)
        processedMetadataOpIds.insert(op.opId)
        importedMetadataSeqByDeviceId[op.deviceId] = max(importedMetadataSeqByDeviceId[op.deviceId] ?? 0, op.seq)
        applyMetadataOpState(op)
        markMetadataChanged(at: op.occurredAt)
        persistMetadataSyncState()
    }

    private func applyRemoteMetadataOp(_ op: BookkeepingMetadataOp) {
        guard op.schemaVersion == 1 else { return }
        guard op.ledgerId == "default", !op.deviceId.isEmpty, op.seq > 0, !op.entityId.isEmpty else { return }
        guard hasValidMetadataPayload(for: op) else { return }
        guard !processedMetadataOpIds.contains(op.opId) else { return }
        guard shouldApplyMetadataOp(op) else {
            processedMetadataOpIds.insert(op.opId)
            importedMetadataSeqByDeviceId[op.deviceId] = max(importedMetadataSeqByDeviceId[op.deviceId] ?? 0, op.seq)
            sqliteStore.recordRemoteMetadataOp(op)
            sqliteStore.recordProcessedOp(domain: .metadata, opId: op.opId, deviceId: op.deviceId, seq: op.seq, applied: false, skippedReason: "stale")
            persistMetadataSyncState()
            return
        }

        switch op.entity {
        case .account:
            applyRemoteAccountOp(op)
        case .category:
            applyRemoteCategoryOp(op)
        }

        processedMetadataOpIds.insert(op.opId)
        importedMetadataSeqByDeviceId[op.deviceId] = max(importedMetadataSeqByDeviceId[op.deviceId] ?? 0, op.seq)
        sqliteStore.recordRemoteMetadataOp(op)
        sqliteStore.recordProcessedOp(domain: .metadata, opId: op.opId, deviceId: op.deviceId, seq: op.seq, applied: true)
        applyMetadataOpState(op)
        updateMetadataSyncMetadata(at: op.occurredAt, deviceId: op.deviceId)
    }

    private func applyRemoteAccountOp(_ op: BookkeepingMetadataOp) {
        switch op.action {
        case .create, .update, .archive, .upsert:
            guard var account = op.payload?.account else { return }
            account.id = op.entityId
            let baseBalanceText = Self.normalizedBalanceText(account.balanceText)
            accountBaseBalanceTextById[account.id] = baseBalanceText
            account.balanceText = baseBalanceText
            if let index = accounts.firstIndex(where: { $0.id == op.entityId }) {
                accounts[index] = account
            } else {
                accounts.append(account)
            }
        case .delete:
            if isAccountReferenced(id: op.entityId), let index = accounts.firstIndex(where: { $0.id == op.entityId }) {
                accounts[index].archivedAt = accounts[index].archivedAt ?? op.occurredAt
                accounts[index].isDefault = false
            } else {
                accounts.removeAll { $0.id == op.entityId }
                accountBaseBalanceTextById.removeValue(forKey: op.entityId)
            }
        }
    }

    private func applyRemoteCategoryOp(_ op: BookkeepingMetadataOp) {
        switch op.action {
        case .create, .update, .archive, .upsert:
            guard var category = op.payload?.category else { return }
            category.id = op.entityId
            if let index = categories.firstIndex(where: { $0.id == op.entityId }) {
                categories[index] = category
            } else {
                categories.append(category)
            }
        case .delete:
            if isAnyCategoryReferenced(ids: [op.entityId]), let index = categories.firstIndex(where: { $0.id == op.entityId }) {
                categories[index].archivedAt = categories[index].archivedAt ?? op.occurredAt
                categories[index].isDefault = false
            } else {
                categories.removeAll { $0.id == op.entityId }
            }
        }
    }

    private func hasValidMetadataPayload(for op: BookkeepingMetadataOp) -> Bool {
        if op.action == .delete {
            return true
        }

        switch op.entity {
        case .account:
            return op.payload?.account != nil
        case .category:
            return op.payload?.category != nil
        }
    }

    private func shouldApplyMetadataOp(_ op: BookkeepingMetadataOp) -> Bool {
        LedgerOpReplayer.shouldApply(
            op,
            currentSortKeysById: metadataOpSortKeysById,
            deletedSortKeysById: deletedMetadataOpSortKeysById
        )
    }

    private func applyMetadataOpState(_ op: BookkeepingMetadataOp) {
        LedgerOpReplayer.applyState(
            op,
            currentSortKeysById: &metadataOpSortKeysById,
            deletedSortKeysById: &deletedMetadataOpSortKeysById
        )
    }

    private func initializeMetadataSyncStateIfNeeded() {
        guard localMetadataOps.isEmpty, processedMetadataOpIds.isEmpty else { return }

        for account in accounts {
            let syncAccount = metadataAccountPayload(account)
            let op = BookkeepingMetadataOp(
                deviceId: DeviceIdentity.currentDeviceId,
                seq: nextMetadataOpSeq,
                entity: .account,
                entityId: account.id,
                action: .create,
                occurredAt: metadataUpdatedAt,
                createdAt: metadataUpdatedAt,
                payload: BookkeepingMetadataOpPayload(account: syncAccount, category: nil)
            )
            nextMetadataOpSeq += 1
            localMetadataOps.append(op)
            processedMetadataOpIds.insert(op.opId)
            importedMetadataSeqByDeviceId[op.deviceId] = max(importedMetadataSeqByDeviceId[op.deviceId] ?? 0, op.seq)
            metadataOpSortKeysById[BookkeepingMetadataOp.replayEntityKey(entity: .account, id: account.id)] = op.sortKey
        }

        for category in categories {
            let op = BookkeepingMetadataOp(
                deviceId: DeviceIdentity.currentDeviceId,
                seq: nextMetadataOpSeq,
                entity: .category,
                entityId: category.id,
                action: .create,
                occurredAt: metadataUpdatedAt,
                createdAt: metadataUpdatedAt,
                payload: BookkeepingMetadataOpPayload(account: nil, category: category)
            )
            nextMetadataOpSeq += 1
            localMetadataOps.append(op)
            processedMetadataOpIds.insert(op.opId)
            importedMetadataSeqByDeviceId[op.deviceId] = max(importedMetadataSeqByDeviceId[op.deviceId] ?? 0, op.seq)
            metadataOpSortKeysById[BookkeepingMetadataOp.replayEntityKey(entity: .category, id: category.id)] = op.sortKey
        }

        persistMetadataSyncState()
    }

    private func backupPendingTransactionOps(
        configuration: SyncConfiguration,
        secrets: SyncSecrets,
        forceFullUpload: Bool = false
    ) async throws {
        initializeTransactionSyncStateIfNeeded()
        let uploadCandidates = sqliteStore.pendingTransactionOps(forceFullUpload: forceFullUpload)
        guard !uploadCandidates.isEmpty else { return }

        let pendingFileIndexes = Set(uploadCandidates.map(\.fileIndex))
        let opsToWrite = sqliteStore.transactionOps(fileIndexes: pendingFileIndexes)
        try await ledgerSyncFacade.backupTransactions(
            ops: opsToWrite,
            configuration: configuration,
            secrets: secrets
        )
        uploadedTransactionOpIds.formUnion(opsToWrite.map(\.opId))
        sqliteStore.markOpsUploaded(domain: .transactions, opIds: opsToWrite.map(\.opId))
        persistTransactionSyncState()
    }

    private func backupPendingTemplateOps(
        configuration: SyncConfiguration,
        secrets: SyncSecrets,
        forceFullUpload: Bool = false
    ) async throws {
        initializeTemplateSyncStateIfNeeded()
        let uploadCandidates = sqliteStore.pendingTemplateOps(forceFullUpload: forceFullUpload)
        guard !uploadCandidates.isEmpty else { return }

        let pendingFileIndexes = Set(uploadCandidates.map(\.fileIndex))
        let opsToWrite = sqliteStore.templateOps(fileIndexes: pendingFileIndexes)
        try await ledgerSyncFacade.backupTemplates(
            ops: opsToWrite,
            configuration: configuration,
            secrets: secrets
        )
        uploadedTemplateOpIds.formUnion(opsToWrite.map(\.opId))
        sqliteStore.markOpsUploaded(domain: .templates, opIds: opsToWrite.map(\.opId))
        persistTemplateSyncState()
    }

    private func backupPendingBudgetOps(
        configuration: SyncConfiguration,
        secrets: SyncSecrets,
        forceFullUpload: Bool = false
    ) async throws {
        initializeBudgetSyncStateIfNeeded()
        let uploadCandidates = sqliteStore.pendingBudgetOps(forceFullUpload: forceFullUpload)
        guard !uploadCandidates.isEmpty else { return }

        let pendingFileIndexes = Set(uploadCandidates.map(\.fileIndex))
        let opsToWrite = sqliteStore.budgetOps(fileIndexes: pendingFileIndexes)
        try await ledgerSyncFacade.backupBudgets(
            ops: opsToWrite,
            configuration: configuration,
            secrets: secrets
        )
        uploadedBudgetOpIds.formUnion(opsToWrite.map(\.opId))
        sqliteStore.markOpsUploaded(domain: .budgets, opIds: opsToWrite.map(\.opId))
        persistBudgetSyncState()
    }

    @discardableResult
    private func importTransactionOps(
        configuration: SyncConfiguration,
        secrets: SyncSecrets
    ) async throws -> Bool {
        let remoteOps = try await ledgerSyncFacade.importTransactions(
            configuration: configuration,
            secrets: secrets
        )
        let unappliedOps = remoteOps
            .filter { !processedTransactionOpIds.contains($0.opId) }
            .sorted(by: LedgerOpReplayer.replaySort)

        guard !unappliedOps.isEmpty else {
            return false
        }

        for op in unappliedOps {
            applyRemoteTransactionOp(op)
        }

        transactions.sort(by: Self.transactionSort)
        lastDraft = transactions.first
        recomputeAccountBalancesFromBase()
        persistAccounts()
        persistTransactions()
        persistLastDraft()
        persistTransactionsMetadata()
        persistTransactionSyncState()
        persistWidgetSnapshot()
        return true
    }

    @discardableResult
    private func importTemplateOps(
        configuration: SyncConfiguration,
        secrets: SyncSecrets
    ) async throws -> Bool {
        initializeTemplateSyncStateIfNeeded()
        let remoteOps = try await ledgerSyncFacade.importTemplates(
            configuration: configuration,
            secrets: secrets
        )
        let unappliedOps = remoteOps
            .filter { !processedTemplateOpIds.contains($0.opId) }
            .sorted(by: LedgerOpReplayer.replaySort)

        guard !unappliedOps.isEmpty else {
            return false
        }

        for op in unappliedOps {
            applyRemoteTemplateOp(op)
        }

        normalizeTransactionTemplates()
        persistTransactionTemplates()
        persistTemplateSyncState()
        return true
    }

    @discardableResult
    private func importBudgetOps(
        configuration: SyncConfiguration,
        secrets: SyncSecrets
    ) async throws -> Bool {
        initializeBudgetSyncStateIfNeeded()
        let remoteOps = try await ledgerSyncFacade.importBudgets(
            configuration: configuration,
            secrets: secrets
        )
        let unappliedOps = remoteOps
            .filter { !processedBudgetOpIds.contains($0.opId) }
            .sorted(by: LedgerOpReplayer.replaySort)

        guard !unappliedOps.isEmpty else {
            return false
        }

        for op in unappliedOps {
            applyRemoteBudgetOp(op)
        }

        normalizeBudgets()
        persistBudgets()
        persistBudgetSyncState()
        return true
    }

    private func appendLocalTransactionOp(action: BookkeepingTransactionOpAction, transaction: DraftTransaction, occurredAt: Date = Date()) {
        let op = BookkeepingTransactionOp(
            deviceId: DeviceIdentity.currentDeviceId,
            seq: nextTransactionOpSeq,
            entityId: transaction.id,
            action: action,
            occurredAt: occurredAt,
            payload: action == .delete ? nil : transaction
        )
        nextTransactionOpSeq += 1
        localTransactionOps.append(op)
        processedTransactionOpIds.insert(op.opId)
        importedTransactionSeqByDeviceId[op.deviceId] = max(importedTransactionSeqByDeviceId[op.deviceId] ?? 0, op.seq)
        applyTransactionOpState(op)
        markTransactionsChanged(at: occurredAt)
        persistTransactionSyncState()
    }

    private func appendLocalTemplateOp(action: BookkeepingTemplateOpAction, template: DraftTransactionTemplate, occurredAt: Date = Date()) {
        let op = BookkeepingTemplateOp(
            deviceId: DeviceIdentity.currentDeviceId,
            seq: nextTemplateOpSeq,
            entityId: template.id,
            action: action,
            occurredAt: occurredAt,
            payload: action == .delete ? nil : normalizedTransactionTemplate(template)
        )
        nextTemplateOpSeq += 1
        localTemplateOps.append(op)
        processedTemplateOpIds.insert(op.opId)
        importedTemplateSeqByDeviceId[op.deviceId] = max(importedTemplateSeqByDeviceId[op.deviceId] ?? 0, op.seq)
        applyTemplateOpState(op)
        markTemplatesChanged()
        persistTemplateSyncState()
    }

    private func appendLocalBudgetOp(action: BookkeepingBudgetOpAction, budget: DraftBudget, occurredAt: Date = Date()) {
        let op = BookkeepingBudgetOp(
            deviceId: DeviceIdentity.currentDeviceId,
            seq: nextBudgetOpSeq,
            entityId: budget.id,
            action: action,
            occurredAt: occurredAt,
            payload: action == .delete ? nil : normalizedBudget(budget)
        )
        nextBudgetOpSeq += 1
        localBudgetOps.append(op)
        processedBudgetOpIds.insert(op.opId)
        importedBudgetSeqByDeviceId[op.deviceId] = max(importedBudgetSeqByDeviceId[op.deviceId] ?? 0, op.seq)
        applyBudgetOpState(op)
        markBudgetsChanged()
        persistBudgetSyncState()
    }

    private func applyRemoteTransactionOp(_ op: BookkeepingTransactionOp) {
        guard op.schemaVersion == 1, op.entity == "transaction" else { return }
        guard op.ledgerId == "default", !op.deviceId.isEmpty, op.seq > 0, !op.entityId.isEmpty else { return }
        guard op.action == .delete || op.payload != nil else { return }
        guard !processedTransactionOpIds.contains(op.opId) else { return }
        guard shouldApplyTransactionOp(op) else {
            processedTransactionOpIds.insert(op.opId)
            importedTransactionSeqByDeviceId[op.deviceId] = max(importedTransactionSeqByDeviceId[op.deviceId] ?? 0, op.seq)
            sqliteStore.recordRemoteTransactionOp(op)
            sqliteStore.recordProcessedOp(domain: .transactions, opId: op.opId, deviceId: op.deviceId, seq: op.seq, applied: false, skippedReason: "stale")
            persistTransactionSyncState()
            return
        }

        switch op.action {
        case .create, .update:
            guard let payload = op.payload else { break }
            var normalized = normalizedTransactionAmounts(payload)
            normalized.id = op.entityId
            if let index = transactions.firstIndex(where: { $0.id == op.entityId }) {
                transactions[index] = normalized
            } else {
                transactions.append(normalized)
            }
        case .delete:
            transactions.removeAll { $0.id == op.entityId }
            deletedTransactionOpSortKeysById[op.entityId] = op.sortKey
        }

        processedTransactionOpIds.insert(op.opId)
        importedTransactionSeqByDeviceId[op.deviceId] = max(importedTransactionSeqByDeviceId[op.deviceId] ?? 0, op.seq)
        sqliteStore.recordRemoteTransactionOp(op)
        sqliteStore.recordProcessedOp(domain: .transactions, opId: op.opId, deviceId: op.deviceId, seq: op.seq, applied: true)
        applyTransactionOpState(op)
        updateTransactionsSyncMetadata(at: op.occurredAt, deviceId: op.deviceId)
    }

    private func shouldApplyTransactionOp(_ op: BookkeepingTransactionOp) -> Bool {
        LedgerOpReplayer.shouldApply(
            op,
            currentSortKeysById: transactionOpSortKeysById,
            deletedSortKeysById: deletedTransactionOpSortKeysById
        )
    }

    private func applyTransactionOpState(_ op: BookkeepingTransactionOp) {
        LedgerOpReplayer.applyState(
            op,
            currentSortKeysById: &transactionOpSortKeysById,
            deletedSortKeysById: &deletedTransactionOpSortKeysById
        )
    }

    private func applyRemoteTemplateOp(_ op: BookkeepingTemplateOp) {
        guard op.schemaVersion == 1, op.entity == "transactionTemplate" else { return }
        guard op.ledgerId == "default", !op.deviceId.isEmpty, op.seq > 0, !op.entityId.isEmpty else { return }
        guard op.action == .delete || op.payload != nil else { return }
        guard !processedTemplateOpIds.contains(op.opId) else { return }
        guard shouldApplyTemplateOp(op) else {
            processedTemplateOpIds.insert(op.opId)
            importedTemplateSeqByDeviceId[op.deviceId] = max(importedTemplateSeqByDeviceId[op.deviceId] ?? 0, op.seq)
            sqliteStore.recordRemoteTemplateOp(op)
            sqliteStore.recordProcessedOp(domain: .templates, opId: op.opId, deviceId: op.deviceId, seq: op.seq, applied: false, skippedReason: "stale")
            persistTemplateSyncState()
            return
        }

        switch op.action {
        case .create, .update:
            guard let payload = op.payload else { break }
            var normalized = normalizedTransactionTemplate(payload)
            normalized.id = op.entityId
            guard !normalized.name.isEmpty, normalized.kind != .transfer, Self.normalizedPositiveAmountText(normalized.amountText) != nil else {
                processedTemplateOpIds.insert(op.opId)
                importedTemplateSeqByDeviceId[op.deviceId] = max(importedTemplateSeqByDeviceId[op.deviceId] ?? 0, op.seq)
                sqliteStore.recordRemoteTemplateOp(op)
                sqliteStore.recordProcessedOp(domain: .templates, opId: op.opId, deviceId: op.deviceId, seq: op.seq, applied: false, skippedReason: "invalidPayload")
                persistTemplateSyncState()
                return
            }
            if let index = transactionTemplates.firstIndex(where: { $0.id == op.entityId }) {
                transactionTemplates[index] = normalized
            } else {
                transactionTemplates.append(normalized)
            }
        case .delete:
            transactionTemplates.removeAll { $0.id == op.entityId }
            deletedTemplateOpSortKeysById[op.entityId] = op.sortKey
        }

        processedTemplateOpIds.insert(op.opId)
        importedTemplateSeqByDeviceId[op.deviceId] = max(importedTemplateSeqByDeviceId[op.deviceId] ?? 0, op.seq)
        sqliteStore.recordRemoteTemplateOp(op)
        sqliteStore.recordProcessedOp(domain: .templates, opId: op.opId, deviceId: op.deviceId, seq: op.seq, applied: true)
        applyTemplateOpState(op)
    }

    private func shouldApplyTemplateOp(_ op: BookkeepingTemplateOp) -> Bool {
        LedgerOpReplayer.shouldApply(
            op,
            currentSortKeysById: templateOpSortKeysById,
            deletedSortKeysById: deletedTemplateOpSortKeysById
        )
    }

    private func applyTemplateOpState(_ op: BookkeepingTemplateOp) {
        LedgerOpReplayer.applyState(
            op,
            currentSortKeysById: &templateOpSortKeysById,
            deletedSortKeysById: &deletedTemplateOpSortKeysById
        )
    }

    private func applyRemoteBudgetOp(_ op: BookkeepingBudgetOp) {
        guard op.schemaVersion == 1, op.entity == "budget" else { return }
        guard op.ledgerId == "default", !op.deviceId.isEmpty, op.seq > 0, !op.entityId.isEmpty else { return }
        guard op.action == .delete || op.payload != nil else { return }
        guard !processedBudgetOpIds.contains(op.opId) else { return }
        guard shouldApplyBudgetOp(op) else {
            processedBudgetOpIds.insert(op.opId)
            importedBudgetSeqByDeviceId[op.deviceId] = max(importedBudgetSeqByDeviceId[op.deviceId] ?? 0, op.seq)
            sqliteStore.recordRemoteBudgetOp(op)
            sqliteStore.recordProcessedOp(domain: .budgets, opId: op.opId, deviceId: op.deviceId, seq: op.seq, applied: false, skippedReason: "stale")
            persistBudgetSyncState()
            return
        }

        switch op.action {
        case .create, .update:
            guard let payload = op.payload else { break }
            var normalized = normalizedBudget(payload)
            normalized.id = op.entityId
            guard hasValidBudgetTarget(normalized), Self.normalizedPositiveAmountText(normalized.amountText) != nil else {
                processedBudgetOpIds.insert(op.opId)
                importedBudgetSeqByDeviceId[op.deviceId] = max(importedBudgetSeqByDeviceId[op.deviceId] ?? 0, op.seq)
                sqliteStore.recordRemoteBudgetOp(op)
                sqliteStore.recordProcessedOp(domain: .budgets, opId: op.opId, deviceId: op.deviceId, seq: op.seq, applied: false, skippedReason: "invalidPayload")
                persistBudgetSyncState()
                return
            }
            if let index = budgets.firstIndex(where: { $0.id == op.entityId }) {
                budgets[index] = normalized
            } else {
                budgets.append(normalized)
            }
        case .delete:
            budgets.removeAll { $0.id == op.entityId }
            deletedBudgetOpSortKeysById[op.entityId] = op.sortKey
        }

        processedBudgetOpIds.insert(op.opId)
        importedBudgetSeqByDeviceId[op.deviceId] = max(importedBudgetSeqByDeviceId[op.deviceId] ?? 0, op.seq)
        sqliteStore.recordRemoteBudgetOp(op)
        sqliteStore.recordProcessedOp(domain: .budgets, opId: op.opId, deviceId: op.deviceId, seq: op.seq, applied: true)
        applyBudgetOpState(op)
    }

    private func shouldApplyBudgetOp(_ op: BookkeepingBudgetOp) -> Bool {
        LedgerOpReplayer.shouldApply(
            op,
            currentSortKeysById: budgetOpSortKeysById,
            deletedSortKeysById: deletedBudgetOpSortKeysById
        )
    }

    private func applyBudgetOpState(_ op: BookkeepingBudgetOp) {
        LedgerOpReplayer.applyState(
            op,
            currentSortKeysById: &budgetOpSortKeysById,
            deletedSortKeysById: &deletedBudgetOpSortKeysById
        )
    }

    private func initializeTransactionSyncStateIfNeeded() {
        if !accountBaseBalanceTextById.isEmpty {
            initializeMissingBaseBalances()
        } else {
            accountBaseBalanceTextById = Dictionary(
                uniqueKeysWithValues: accounts.map { account in
                    (account.id, Self.plainAmountText(from: decimalValue(from: account.balanceText) - transactionBalanceDelta(forAccountId: account.id)))
                }
            )
        }

        guard localTransactionOps.isEmpty, processedTransactionOpIds.isEmpty, !transactions.isEmpty else {
            return
        }

        for transaction in transactions.sorted(by: { $0.createdAt < $1.createdAt }) {
            let op = BookkeepingTransactionOp(
                deviceId: DeviceIdentity.currentDeviceId,
                seq: nextTransactionOpSeq,
                entityId: transaction.id,
                action: .create,
                occurredAt: transaction.createdAt,
                createdAt: transaction.createdAt,
                payload: transaction
            )
            nextTransactionOpSeq += 1
            localTransactionOps.append(op)
            processedTransactionOpIds.insert(op.opId)
            importedTransactionSeqByDeviceId[op.deviceId] = max(importedTransactionSeqByDeviceId[op.deviceId] ?? 0, op.seq)
            transactionOpSortKeysById[transaction.id] = op.sortKey
        }
    }

    private func initializeTemplateSyncStateIfNeeded() {
        guard localTemplateOps.isEmpty, processedTemplateOpIds.isEmpty, !transactionTemplates.isEmpty else {
            return
        }

        for template in transactionTemplates.sorted(by: { $0.createdAt < $1.createdAt }) {
            let normalized = normalizedTransactionTemplate(template)
            let op = BookkeepingTemplateOp(
                deviceId: DeviceIdentity.currentDeviceId,
                seq: nextTemplateOpSeq,
                entityId: template.id,
                action: .create,
                occurredAt: template.createdAt,
                createdAt: template.createdAt,
                payload: normalized
            )
            nextTemplateOpSeq += 1
            localTemplateOps.append(op)
            processedTemplateOpIds.insert(op.opId)
            importedTemplateSeqByDeviceId[op.deviceId] = max(importedTemplateSeqByDeviceId[op.deviceId] ?? 0, op.seq)
            templateOpSortKeysById[template.id] = op.sortKey
        }
        persistTemplateSyncState()
    }

    private func initializeBudgetSyncStateIfNeeded() {
        guard localBudgetOps.isEmpty, processedBudgetOpIds.isEmpty, !budgets.isEmpty else {
            return
        }

        for budget in budgets.sorted(by: { $0.createdAt < $1.createdAt }) {
            let normalized = normalizedBudget(budget)
            let op = BookkeepingBudgetOp(
                deviceId: DeviceIdentity.currentDeviceId,
                seq: nextBudgetOpSeq,
                entityId: budget.id,
                action: .create,
                occurredAt: budget.createdAt,
                createdAt: budget.createdAt,
                payload: normalized
            )
            nextBudgetOpSeq += 1
            localBudgetOps.append(op)
            processedBudgetOpIds.insert(op.opId)
            importedBudgetSeqByDeviceId[op.deviceId] = max(importedBudgetSeqByDeviceId[op.deviceId] ?? 0, op.seq)
            budgetOpSortKeysById[budget.id] = op.sortKey
        }
        persistBudgetSyncState()
    }

    private func initializeMissingBaseBalances() {
        for account in accounts where accountBaseBalanceTextById[account.id] == nil {
            accountBaseBalanceTextById[account.id] = Self.plainAmountText(from: decimalValue(from: account.balanceText) - transactionBalanceDelta(forAccountId: account.id))
        }
    }

    private func recomputeAccountBalancesFromBase() {
        initializeMissingBaseBalances()
        accounts = accounts.map { account in
            var updated = account
            let baseBalance = decimalValue(from: accountBaseBalanceTextById[account.id] ?? account.balanceText)
            updated.balanceText = Self.plainAmountText(from: baseBalance + transactionBalanceDelta(forAccountId: account.id))
            return updated
        }
    }

    private func transactionBalanceDelta(forAccountId accountId: String) -> Decimal {
        transactions.reduce(Decimal(0)) { partialResult, transaction in
            partialResult + transactionBalanceDelta(transaction, forAccountId: accountId)
        }
    }

    private func transactionBalanceDelta(_ transaction: DraftTransaction, forAccountId accountId: String) -> Decimal {
        switch transaction.kind {
        case .expense:
            return transaction.accountId == accountId ? -decimalValue(from: transaction.amountText) : 0
        case .income:
            return transaction.accountId == accountId ? decimalValue(from: transaction.amountText) : 0
        case .transfer:
            var delta = Decimal(0)
            if transaction.fromAccountId == accountId {
                delta -= decimalValue(from: transaction.amountText)
            }
            if transaction.toAccountId == accountId {
                delta += decimalValue(from: transaction.transferInAmountText ?? transaction.amountText)
            }
            return delta
        }
    }

    private func markMetadataChanged(at date: Date = Date()) {
        metadataRevision += 1
        metadataUpdatedAt = date
        metadataUpdatedByDeviceId = DeviceIdentity.currentDeviceId
        persistMetadata()
        localMetadataChangeToken += 1
    }

    private func updateMetadataSyncMetadata(at date: Date, deviceId: String) {
        metadataRevision += 1
        metadataUpdatedAt = date
        metadataUpdatedByDeviceId = deviceId
        persistMetadata()
    }

    private func markTransactionsChanged(at date: Date = Date()) {
        updateTransactionsSyncMetadata(at: date, deviceId: DeviceIdentity.currentDeviceId)
        localTransactionsChangeToken += 1
    }

    private func markTemplatesChanged() {
        localTemplatesChangeToken += 1
    }

    private func markBudgetsChanged() {
        localBudgetsChangeToken += 1
    }

    private func updateTransactionsSyncMetadata(at date: Date, deviceId: String) {
        transactionsRevision += 1
        transactionsUpdatedAt = date
        transactionsUpdatedByDeviceId = deviceId
        persistTransactionsMetadata()
    }

    private func persistMetadata() {
        persistLedgerSnapshot()
    }

    private func persistTransactionsMetadata() {
        persistLedgerSnapshot()
    }

    private func persistMetadataSyncState() {
        persistLedgerSnapshot()
    }

    private func persistTransactionSyncState() {
        persistLedgerSnapshot()
    }

    private func persistTemplateSyncState() {
        persistLedgerSnapshot()
    }

    private func persistBudgetSyncState() {
        persistLedgerSnapshot()
    }

    private func normalizeTransactionsAfterMetadataChange() {
        lastDraft = transactions.first
    }

    private func normalizeTransactionTemplates() {
        transactionTemplates = transactionTemplates
            .filter { $0.kind != .transfer }
            .map(normalizedTransactionTemplate)
            .filter { !$0.name.isEmpty }
            .sorted(by: Self.transactionTemplateSort)
    }

    private func normalizedTransactionTemplate(_ template: DraftTransactionTemplate) -> DraftTransactionTemplate {
        var normalized = template
        normalized.name = normalized.name.trimmingCharacters(in: .whitespacesAndNewlines)
        normalized.note = normalized.note.trimmingCharacters(in: .whitespacesAndNewlines)
        normalized.amountText = DraftAmountFormatter.normalizedAmountText(template.amountText, allowNegative: false) ?? "0"
        return normalized
    }

    private func normalizeBudgets() {
        budgets = budgets
            .map(normalizedBudget)
            .filter { budget in
                hasValidBudgetTarget(budget) && Self.normalizedPositiveAmountText(budget.amountText) != nil
            }
            .sorted(by: Self.budgetSort)
    }

    private func normalizedBudget(_ budget: DraftBudget) -> DraftBudget {
        var normalized = budget
        normalized.name = normalized.name.trimmingCharacters(in: .whitespacesAndNewlines)
        normalized.amountText = DraftAmountFormatter.normalizedAmountText(budget.amountText, allowNegative: false) ?? "0"
        if normalized.scope == .overall {
            normalized.targetId = nil
        }
        return normalized
    }

    private func makeBudget(
        id: String,
        existingCreatedAt: Date?,
        name: String,
        scope: DraftBudgetScope,
        targetId: String?,
        amountText: String,
        isEnabled: Bool
    ) -> DraftBudget? {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let normalizedAmountText = Self.normalizedPositiveAmountText(amountText) else {
            messageKey = "budgets.error.invalidAmount"
            return nil
        }

        let resolvedTargetId: String?
        switch scope {
        case .overall:
            resolvedTargetId = nil
        case .category:
            guard let targetId, isActiveCategory(id: targetId, kind: .expense) else {
                messageKey = "budgets.error.targetRequired"
                return nil
            }
            resolvedTargetId = targetId
        case .account:
            guard let targetId, isActiveAccount(id: targetId) else {
                messageKey = "budgets.error.targetRequired"
                return nil
            }
            resolvedTargetId = targetId
        }

        let now = Date()
        return DraftBudget(
            id: id,
            name: trimmedName,
            scope: scope,
            targetId: resolvedTargetId,
            amountText: normalizedAmountText,
            isEnabled: isEnabled,
            createdAt: existingCreatedAt ?? now,
            updatedAt: now
        )
    }

    private func hasValidBudgetTarget(_ budget: DraftBudget) -> Bool {
        switch budget.scope {
        case .overall:
            return true
        case .category:
            guard let targetId = budget.targetId else { return false }
            return categories.contains { $0.id == targetId && $0.kind == .expense }
        case .account:
            guard let targetId = budget.targetId else { return false }
            return accounts.contains { $0.id == targetId }
        }
    }

    private func budgetIncludes(_ budget: DraftBudget, transaction: DraftTransaction) -> Bool {
        guard transaction.kind == .expense else { return false }

        switch budget.scope {
        case .overall:
            return true
        case .category:
            guard let targetId = budget.targetId, let categoryId = transaction.categoryId else { return false }
            return categoryId == targetId || categoryDescendantIds(for: targetId).contains(categoryId)
        case .account:
            return transaction.accountId == budget.targetId
        }
    }

    private func monthlyExpense(for budget: DraftBudget, now: Date, calendar: Calendar) -> Decimal {
        guard let monthInterval = calendar.dateInterval(of: .month, for: now) else { return 0 }

        return transactions.reduce(Decimal(0)) { partialResult, transaction in
            guard monthInterval.contains(transaction.date), budgetIncludes(budget, transaction: transaction) else {
                return partialResult
            }

            return partialResult + decimalValue(from: transaction.amountText)
        }
    }

    private func isActiveAccount(id: String) -> Bool {
        accounts.contains { $0.id == id && !$0.isArchived }
    }

    private func isActiveCategory(id: String, kind: DraftEntryKind) -> Bool {
        categories.contains { $0.id == id && $0.kind == kind && !$0.isArchived }
    }

    private func hierarchyItems(from category: DraftCategory, depth: Int, visitedIds: Set<String>) -> [DraftCategoryHierarchyItem] {
        guard !visitedIds.contains(category.id), depth <= Self.maxCategoryDepth else {
            return []
        }

        let nextVisitedIds = visitedIds.union([category.id])
        let children = categories.filter { child in
            child.kind == category.kind && child.parentId == category.id && !child.isArchived
        }

        return [DraftCategoryHierarchyItem(category: category, depth: depth)] + children.flatMap { child in
            hierarchyItems(from: child, depth: depth + 1, visitedIds: nextVisitedIds)
        }
    }

    private func categoryDepth(for id: String) -> Int {
        categoryPath(for: id).count
    }

    private func categoryPath(for id: String) -> [DraftCategory] {
        guard let category = categories.first(where: { $0.id == id }) else {
            return []
        }

        var path = [category]
        var visitedIds = Set([category.id])
        var currentCategory = category

        while
            let parentId = currentCategory.parentId,
            !visitedIds.contains(parentId),
            let parent = categories.first(where: { $0.id == parentId && $0.kind == category.kind })
        {
            path.append(parent)
            visitedIds.insert(parent.id)
            currentCategory = parent
        }

        return path.reversed()
    }

    private func categoryDescendantIds(for id: String) -> Set<String> {
        var descendantIds = Set<String>()
        var pendingIds = [id]

        while let parentId = pendingIds.popLast() {
            let children = categories.filter { $0.parentId == parentId }
            for child in children where !descendantIds.contains(child.id) {
                descendantIds.insert(child.id)
                pendingIds.append(child.id)
            }
        }

        return descendantIds
    }

    private func maxRelativeDescendantDepth(from id: String, visitedIds: Set<String> = []) -> Int {
        guard !visitedIds.contains(id) else {
            return 1
        }

        let nextVisitedIds = visitedIds.union([id])
        let children = childCategories(of: id)
        guard !children.isEmpty else {
            return 1
        }

        return 1 + (children.map { maxRelativeDescendantDepth(from: $0.id, visitedIds: nextVisitedIds) }.max() ?? 0)
    }

    private func normalizeDefaultNames() {
        accounts = accounts.map { account in
            var normalized = account

            guard
                let key = Self.defaultNameKeyById[account.id],
                account.name.isEmpty || account.name == key
            else {
                return normalizedAccountMetadata(normalized)
            }

            normalized.name = Self.localized(key)
            return normalizedAccountMetadata(normalized)
        }

        categories = categories.map { category in
            var normalized = category

            guard
                let key = Self.defaultNameKeyById[category.id],
                category.name.isEmpty || category.name == key
            else {
                return normalizedCategoryMetadata(normalized)
            }

            normalized.name = Self.localized(key)
            return normalizedCategoryMetadata(normalized)
        }
    }

    private func normalizeDefaultSelections() {
        normalizeDefaultAccounts()
        for kind in [DraftEntryKind.expense, .income] {
            normalizeDefaultCategories(kind: kind)
        }
    }

    private func normalizeDefaultAccounts() {
        let activeAccounts = accounts.filter { !$0.isArchived }
        let selectedDefaultId = activeAccounts.first { $0.isDefault }?.id ?? activeAccounts.first?.id

        accounts = accounts.map { account in
            var normalized = account
            normalized.isDefault = !account.isArchived && account.id == selectedDefaultId
            return normalized
        }
    }

    private func normalizeDefaultCategories(kind: DraftEntryKind) {
        let categoryIds = categories.filter { $0.kind == kind && $0.parentId == nil && !$0.isArchived }.map(\.id)
        guard let fallbackId = categoryIds.first else { return }

        let selectedDefaultId = categories.first { category in
            category.kind == kind && category.parentId == nil && !category.isArchived && category.isDefault
        }?.id ?? fallbackId

        categories = categories.map { category in
            var normalized = category
            if category.kind == kind {
                normalized.isDefault = !category.isArchived && category.parentId == nil && category.id == selectedDefaultId
            }
            return normalized
        }
    }

    private func normalizeCategoryHierarchy() {
        for index in categories.indices {
            guard let parentId = categories[index].parentId else {
                continue
            }

            if categories[index].isArchived || !canUseParent(parentId, for: categories[index].id, kind: categories[index].kind) {
                categories[index].parentId = nil
            }

            if categories[index].parentId != nil {
                categories[index].isDefault = false
            }
        }
    }

    private func normalizedAccountMetadata(_ account: DraftAccount) -> DraftAccount {
        var normalized = account
        normalized.iconName = Self.fontAwesomeName(for: normalized.iconName)

        if let defaults = Self.defaultAccountMetadataById[account.id] {
            if normalized.iconName.isEmpty {
                normalized.iconName = defaults.iconName
            }
            if normalized.colorHex.isEmpty {
                normalized.colorHex = defaults.colorHex
            }
            if normalized.type == .cash, defaults.type != .cash, account.id != "account.cash" {
                normalized.type = defaults.type
            }
        }
        normalized.balanceText = Self.normalizedBalanceText(normalized.balanceText)

        return normalized
    }

    private func normalizedCategoryMetadata(_ category: DraftCategory) -> DraftCategory {
        var normalized = category
        normalized.iconName = Self.fontAwesomeName(for: normalized.iconName)

        if let defaults = Self.defaultCategoryMetadataById[category.id] {
            if normalized.iconName.isEmpty {
                normalized.iconName = defaults.iconName
            }
            if normalized.colorHex.isEmpty {
                normalized.colorHex = defaults.colorHex
            }
        }

        return normalized
    }

    private func persistAccounts() {
        persistLedgerSnapshot()
    }

    private func persistCategories() {
        persistLedgerSnapshot()
    }

    private func persistTransactions() {
        persistLedgerSnapshot()
    }

    private func persistTransactionTemplates() {
        persistLedgerSnapshot()
    }

    private func persistBudgets() {
        persistLedgerSnapshot()
    }

    private func persistLastDraft() {
        persistLedgerSnapshot()
    }

    private func persistLedgerSnapshot() {
        sqliteStore.saveLedgerSnapshot(makeLedgerSnapshot())
    }

    private func makeLedgerSnapshot() -> LedgerSnapshot {
        LedgerSnapshot(
            accounts: accounts,
            categories: categories,
            transactions: transactions,
            transactionTemplates: transactionTemplates,
            budgets: budgets,
            lastDraft: lastDraft,
            metadataRevision: metadataRevision,
            metadataUpdatedAt: metadataUpdatedAt,
            metadataUpdatedByDeviceId: metadataUpdatedByDeviceId,
            nextMetadataOpSeq: nextMetadataOpSeq,
            localMetadataOps: localMetadataOps,
            uploadedMetadataOpIds: uploadedMetadataOpIds,
            processedMetadataOpIds: processedMetadataOpIds,
            importedMetadataSeqByDeviceId: importedMetadataSeqByDeviceId,
            metadataOpSortKeysById: metadataOpSortKeysById,
            deletedMetadataOpSortKeysById: deletedMetadataOpSortKeysById,
            transactionsRevision: transactionsRevision,
            transactionsUpdatedAt: transactionsUpdatedAt,
            transactionsUpdatedByDeviceId: transactionsUpdatedByDeviceId,
            nextTransactionOpSeq: nextTransactionOpSeq,
            localTransactionOps: localTransactionOps,
            uploadedTransactionOpIds: uploadedTransactionOpIds,
            processedTransactionOpIds: processedTransactionOpIds,
            importedTransactionSeqByDeviceId: importedTransactionSeqByDeviceId,
            transactionOpSortKeysById: transactionOpSortKeysById,
            deletedTransactionOpSortKeysById: deletedTransactionOpSortKeysById,
            accountBaseBalanceTextById: accountBaseBalanceTextById,
            nextTemplateOpSeq: nextTemplateOpSeq,
            localTemplateOps: localTemplateOps,
            uploadedTemplateOpIds: uploadedTemplateOpIds,
            processedTemplateOpIds: processedTemplateOpIds,
            importedTemplateSeqByDeviceId: importedTemplateSeqByDeviceId,
            templateOpSortKeysById: templateOpSortKeysById,
            deletedTemplateOpSortKeysById: deletedTemplateOpSortKeysById,
            nextBudgetOpSeq: nextBudgetOpSeq,
            localBudgetOps: localBudgetOps,
            uploadedBudgetOpIds: uploadedBudgetOpIds,
            processedBudgetOpIds: processedBudgetOpIds,
            importedBudgetSeqByDeviceId: importedBudgetSeqByDeviceId,
            budgetOpSortKeysById: budgetOpSortKeysById,
            deletedBudgetOpSortKeysById: deletedBudgetOpSortKeysById
        )
    }

    private func persistWidgetSnapshot() {
        WidgetSnapshotStore.save(makeWidgetSnapshot())
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }

    private func makeWidgetSnapshot(now: Date = Date(), calendar: Calendar = .current) -> WidgetLedgerSnapshot {
        let activeAccounts = accounts.filter { !$0.isArchived }
        let totalBalance = activeAccounts.reduce(Decimal(0)) { partialResult, account in
            partialResult + decimalValue(from: account.balanceText)
        }
        let monthInterval = calendar.dateInterval(of: .month, for: now)
        let dayInterval = calendar.dateInterval(of: .day, for: now)
        var monthIncome = Decimal(0)
        var monthExpense = Decimal(0)
        var todayExpense = Decimal(0)
        var monthTransactionCount = 0
        var expenseByCategoryId: [String: Decimal] = [:]
        var dailyIncomeByDay: [Int: Decimal] = [:]
        var dailyExpenseByDay: [Int: Decimal] = [:]

        for transaction in transactions {
            guard let monthInterval, monthInterval.contains(transaction.date) else {
                continue
            }

            monthTransactionCount += 1
            let day = calendar.component(.day, from: transaction.date)

            switch transaction.kind {
            case .income:
                let amount = decimalValue(from: transaction.amountText)
                monthIncome += amount
                dailyIncomeByDay[day, default: 0] += amount
            case .expense:
                let amount = decimalValue(from: transaction.amountText)
                monthExpense += amount
                dailyExpenseByDay[day, default: 0] += amount

                if let dayInterval, dayInterval.contains(transaction.date) {
                    todayExpense += amount
                }
                if let categoryId = transaction.categoryId {
                    expenseByCategoryId[categoryId, default: 0] += amount
                }
            case .transfer:
                break
            }
        }

        let topCategory = expenseByCategoryId.max { lhs, rhs in
            if lhs.value == rhs.value {
                return categoryDisplayName(for: lhs.key) > categoryDisplayName(for: rhs.key)
            }

            return lhs.value < rhs.value
        }
        let monthDayCount = monthInterval.map { calendar.range(of: .day, in: .month, for: $0.start)?.count ?? 31 } ?? 31
        let dailyPoints = (1...monthDayCount).map { day in
            WidgetDailyPoint(
                day: day,
                income: Self.doubleValue(from: dailyIncomeByDay[day] ?? 0),
                expense: Self.doubleValue(from: dailyExpenseByDay[day] ?? 0)
            )
        }
        let recentItems = transactions.prefix(3).map { transaction in
            WidgetRecentTransaction(
                id: transaction.id,
                kind: WidgetRecordKind(rawValue: transaction.kind.rawValue) ?? .expense,
                title: widgetTransactionTitle(for: transaction),
                amountText: widgetAmountText(for: transaction),
                dateText: Self.widgetDateFormatter.string(from: transaction.date)
            )
        }

        return WidgetLedgerSnapshot(
            generatedAt: now,
            totalBalanceText: DraftAmountFormatter.currencyText(from: Self.plainAmountText(from: totalBalance)),
            monthIncomeText: DraftAmountFormatter.currencyText(from: Self.plainAmountText(from: monthIncome)),
            monthExpenseText: DraftAmountFormatter.currencyText(from: Self.plainAmountText(from: monthExpense)),
            monthBalanceText: DraftAmountFormatter.currencyText(from: Self.plainAmountText(from: monthIncome - monthExpense)),
            todayExpenseText: DraftAmountFormatter.currencyText(from: Self.plainAmountText(from: todayExpense)),
            monthTransactionCount: monthTransactionCount,
            topExpenseCategoryName: topCategory.map { categoryDisplayName(for: $0.key) },
            topExpenseCategoryAmountText: topCategory.map { DraftAmountFormatter.currencyText(from: Self.plainAmountText(from: $0.value)) },
            recentTransactions: Array(recentItems),
            dailyPoints: dailyPoints
        )
    }

    private func widgetTransactionTitle(for transaction: DraftTransaction) -> String {
        switch transaction.kind {
        case .expense, .income:
            return categoryDisplayName(for: transaction.categoryId)
        case .transfer:
            return "\(accountName(for: transaction.fromAccountId)) -> \(accountName(for: transaction.toAccountId))"
        }
    }

    private func widgetAmountText(for transaction: DraftTransaction) -> String {
        let amountText = DraftAmountFormatter.currencyText(from: transaction.amountText)
        switch transaction.kind {
        case .expense:
            return "-\(amountText)"
        case .income:
            return "+\(amountText)"
        case .transfer:
            return amountText
        }
    }

    private func applyTransactionToAccountBalances(_ transaction: DraftTransaction, multiplier: Decimal = 1) {
        switch transaction.kind {
        case .expense:
            guard let accountId = transaction.accountId else { return }
            adjustAccountBalance(id: accountId, by: -decimalValue(from: transaction.amountText) * multiplier)
        case .income:
            guard let accountId = transaction.accountId else { return }
            adjustAccountBalance(id: accountId, by: decimalValue(from: transaction.amountText) * multiplier)
        case .transfer:
            if let fromAccountId = transaction.fromAccountId {
                adjustAccountBalance(id: fromAccountId, by: -decimalValue(from: transaction.amountText) * multiplier)
            }
            if let toAccountId = transaction.toAccountId {
                adjustAccountBalance(id: toAccountId, by: decimalValue(from: transaction.transferInAmountText ?? transaction.amountText) * multiplier)
            }
        }
    }

    private func normalizedTransactionAmounts(_ transaction: DraftTransaction) -> DraftTransaction {
        var normalized = transaction
        normalized.amountText = DraftAmountFormatter.normalizedAmountText(transaction.amountText, allowNegative: false) ?? "0"
        if let transferInAmountText = transaction.transferInAmountText {
            normalized.transferInAmountText = DraftAmountFormatter.normalizedAmountText(transferInAmountText, allowNegative: false) ?? normalized.amountText
        }
        return normalized
    }

    private func adjustAccountBalance(id: String, by delta: Decimal) {
        guard let index = accounts.firstIndex(where: { $0.id == id }) else { return }

        let currentBalance = decimalValue(from: accounts[index].balanceText)
        let updatedBalance = currentBalance + delta
        accounts[index].balanceText = Self.plainAmountText(from: updatedBalance)
    }

    private func decimalValue(from text: String) -> Decimal {
        let normalizedText = DraftAmountFormatter.normalizedAmountText(text, allowNegative: true) ?? "0"
        return Decimal(string: normalizedText, locale: Locale(identifier: "en_US_POSIX")) ?? 0
    }

    private static func transactionSort(_ lhs: DraftTransaction, _ rhs: DraftTransaction) -> Bool {
        if lhs.date == rhs.date {
            return lhs.createdAt > rhs.createdAt
        }

        return lhs.date > rhs.date
    }

    private static func transactionTemplateSort(_ lhs: DraftTransactionTemplate, _ rhs: DraftTransactionTemplate) -> Bool {
        if lhs.updatedAt == rhs.updatedAt {
            return lhs.createdAt > rhs.createdAt
        }

        return lhs.updatedAt > rhs.updatedAt
    }

    private static func budgetSort(_ lhs: DraftBudget, _ rhs: DraftBudget) -> Bool {
        if lhs.isEnabled != rhs.isEnabled {
            return lhs.isEnabled && !rhs.isEnabled
        }

        if lhs.updatedAt == rhs.updatedAt {
            return lhs.createdAt > rhs.createdAt
        }

        return lhs.updatedAt > rhs.updatedAt
    }

    private static func plainAmountText(from decimal: Decimal) -> String {
        let number = NSDecimalNumber(decimal: decimal)
        return plainAmountFormatter.string(from: number) ?? number.stringValue
    }

    private static func doubleValue(from decimal: Decimal) -> Double {
        NSDecimalNumber(decimal: decimal).doubleValue
    }

    private static func normalizedPositiveAmountText(_ text: String) -> String? {
        let normalizedText = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")

        guard
            let amountText = DraftAmountFormatter.normalizedAmountText(normalizedText, allowNegative: false),
            let decimal = Decimal(string: amountText, locale: Locale(identifier: "en_US_POSIX")),
            decimal > 0
        else {
            return nil
        }

        return amountText
    }

    private static let plainAmountFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        return formatter
    }()

    private static let widgetDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("M/d")
        return formatter
    }()

    private static let defaultNameKeyById = [
        "account.cash": "management.account.default.cash",
        "account.bankCard": "management.account.default.bankCard",
        "category.expense.food": "management.category.default.food",
        "category.expense.transport": "management.category.default.transport",
        "category.expense.shopping": "management.category.default.shopping",
        "category.expense.daily": "management.category.default.daily",
        "category.expense.housing": "management.category.default.housing",
        "category.income.salary": "management.category.default.salary",
        "category.income.bonus": "management.category.default.bonus",
        "category.income.reimbursement": "management.category.default.reimbursement",
        "category.income.other": "management.category.default.otherIncome"
    ]

    private static let defaultAccountMetadataById: [String: (type: DraftAccountType, iconName: String, colorHex: String)] = [
        "account.cash": (.cash, "money-bill", "#F6C343"),
        "account.bankCard": (.debitCard, "credit-card", "#4F8EF7")
    ]

    private static let defaultCategoryMetadataById: [String: (iconName: String, colorHex: String)] = [
        "category.expense.food": ("utensils", "#F97316"),
        "category.expense.transport": ("bus", "#3B82F6"),
        "category.expense.shopping": ("bag-shopping", "#EC4899"),
        "category.expense.daily": ("cart-shopping", "#10B981"),
        "category.expense.housing": ("house", "#8B5CF6"),
        "category.income.salary": ("briefcase", "#22C55E"),
        "category.income.bonus": ("gift", "#F59E0B"),
        "category.income.reimbursement": ("receipt", "#06B6D4"),
        "category.income.other": ("ellipsis", "#64748B")
    ]

    private static let defaultAccounts = [
        DraftAccount(
            id: "account.cash",
            name: localized("management.account.default.cash"),
            isDefault: true,
            type: .cash,
            iconName: "money-bill",
            colorHex: "#F6C343",
            balanceText: "0"
        ),
        DraftAccount(
            id: "account.bankCard",
            name: localized("management.account.default.bankCard"),
            isDefault: true,
            type: .debitCard,
            iconName: "credit-card",
            colorHex: "#4F8EF7",
            balanceText: "0"
        )
    ]

    private static let defaultCategories = [
        DraftCategory(id: "category.expense.food", name: localized("management.category.default.food"), kind: .expense, iconName: "utensils", colorHex: "#F97316"),
        DraftCategory(id: "category.expense.transport", name: localized("management.category.default.transport"), kind: .expense, iconName: "bus", colorHex: "#3B82F6"),
        DraftCategory(id: "category.expense.shopping", name: localized("management.category.default.shopping"), kind: .expense, iconName: "bag-shopping", colorHex: "#EC4899"),
        DraftCategory(id: "category.expense.daily", name: localized("management.category.default.daily"), kind: .expense, iconName: "cart-shopping", colorHex: "#10B981"),
        DraftCategory(id: "category.expense.housing", name: localized("management.category.default.housing"), kind: .expense, iconName: "house", colorHex: "#8B5CF6"),
        DraftCategory(id: "category.income.salary", name: localized("management.category.default.salary"), kind: .income, iconName: "briefcase", colorHex: "#22C55E"),
        DraftCategory(id: "category.income.bonus", name: localized("management.category.default.bonus"), kind: .income, iconName: "gift", colorHex: "#F59E0B"),
        DraftCategory(id: "category.income.reimbursement", name: localized("management.category.default.reimbursement"), kind: .income, iconName: "receipt", colorHex: "#06B6D4"),
        DraftCategory(id: "category.income.other", name: localized("management.category.default.otherIncome"), kind: .income, iconName: "ellipsis", colorHex: "#64748B")
    ]

    private static func localized(_ key: String) -> String {
        NSLocalizedString(key, comment: "")
    }

    private static func normalizedBalanceText(_ text: String) -> String {
        DraftAmountFormatter.normalizedAmountText(text, allowNegative: false) ?? "0"
    }

    private static func fontAwesomeName(for symbolName: String) -> String {
        let mapping = [
            "banknote.fill": "money-bill",
            "creditcard.fill": "credit-card",
            "wallet.pass.fill": "wallet",
            "building.columns.fill": "building-columns",
            "iphone.gen3": "mobile-screen-button",
            "bitcoinsign.circle.fill": "coins",
            "archivebox.fill": "box-archive",
            "fork.knife": "utensils",
            "bus.fill": "bus",
            "car.fill": "car",
            "bag.fill": "bag-shopping",
            "cart.fill": "cart-shopping",
            "house.fill": "house",
            "cross.case.fill": "kit-medical",
            "gamecontroller.fill": "gamepad",
            "book.fill": "book",
            "briefcase.fill": "briefcase",
            "gift.fill": "gift",
            "doc.text.fill": "file-lines",
            "ellipsis.circle.fill": "ellipsis",
            "questionmark.circle.fill": "circle-question",
            "tag.fill": "tag"
        ]

        return mapping[symbolName] ?? symbolName
    }
}
