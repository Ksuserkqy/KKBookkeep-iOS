import Combine
import Foundation
import SwiftUI

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
    @Published private(set) var lastDraft: DraftTransaction?
    @Published private(set) var messageKey: String?
    @Published private(set) var localMetadataChangeToken = 0
    @Published private(set) var localTransactionsChangeToken = 0

    private let defaults: UserDefaults
    private let syncService: BookkeepingMetadataSyncService
    private let transactionsSyncService: BookkeepingTransactionsSyncService
    private var metadataRevision: Int
    private var metadataUpdatedAt: Date
    private var metadataUpdatedByDeviceId: String
    private var transactionsRevision: Int
    private var transactionsUpdatedAt: Date
    private var transactionsUpdatedByDeviceId: String

    private enum DefaultsKey {
        static let accounts = "draftBookkeeping.accounts"
        static let categories = "draftBookkeeping.categories"
        static let transactions = "draftBookkeeping.transactions"
        static let lastDraft = "draftBookkeeping.lastDraft"
        static let metadataRevision = "draftBookkeeping.metadata.revision"
        static let metadataUpdatedAt = "draftBookkeeping.metadata.updatedAt"
        static let metadataUpdatedByDeviceId = "draftBookkeeping.metadata.updatedByDeviceId"
        static let transactionsRevision = "draftBookkeeping.transactions.revision"
        static let transactionsUpdatedAt = "draftBookkeeping.transactions.updatedAt"
        static let transactionsUpdatedByDeviceId = "draftBookkeeping.transactions.updatedByDeviceId"
    }

    private static let maxCategoryDepth = 3

    init(
        defaults: UserDefaults = .standard,
        syncService: BookkeepingMetadataSyncService = BookkeepingMetadataSyncService(),
        transactionsSyncService: BookkeepingTransactionsSyncService = BookkeepingTransactionsSyncService()
    ) {
        self.defaults = defaults
        self.syncService = syncService
        self.transactionsSyncService = transactionsSyncService
        let hasStoredAccounts = defaults.data(forKey: DefaultsKey.accounts) != nil
        let hasStoredCategories = defaults.data(forKey: DefaultsKey.categories) != nil
        let hasStoredMetadata = defaults.object(forKey: DefaultsKey.metadataRevision) != nil
        let hasStoredTransactionsMetadata = defaults.object(forKey: DefaultsKey.transactionsRevision) != nil
        self.accounts = Self.load([DraftAccount].self, forKey: DefaultsKey.accounts, from: defaults) ?? Self.defaultAccounts
        self.categories = Self.load([DraftCategory].self, forKey: DefaultsKey.categories, from: defaults) ?? Self.defaultCategories
        let storedTransactions = Self.load([DraftTransaction].self, forKey: DefaultsKey.transactions, from: defaults) ?? []
        let legacyDraft = Self.load(DraftTransaction.self, forKey: DefaultsKey.lastDraft, from: defaults)
        let initializedTransactions: [DraftTransaction]
        if storedTransactions.isEmpty, let legacyDraft {
            initializedTransactions = [legacyDraft]
        } else {
            initializedTransactions = storedTransactions.sorted(by: Self.transactionSort)
        }
        self.transactions = initializedTransactions
        self.lastDraft = initializedTransactions.first
        if hasStoredMetadata {
            self.metadataRevision = defaults.integer(forKey: DefaultsKey.metadataRevision)
            self.metadataUpdatedAt = defaults.object(forKey: DefaultsKey.metadataUpdatedAt) as? Date ?? Date(timeIntervalSince1970: 0)
            self.metadataUpdatedByDeviceId = defaults.string(forKey: DefaultsKey.metadataUpdatedByDeviceId) ?? DeviceIdentity.currentDeviceId
        } else if hasStoredAccounts || hasStoredCategories {
            self.metadataRevision = 1
            self.metadataUpdatedAt = Date()
            self.metadataUpdatedByDeviceId = DeviceIdentity.currentDeviceId
        } else {
            self.metadataRevision = 0
            self.metadataUpdatedAt = Date(timeIntervalSince1970: 0)
            self.metadataUpdatedByDeviceId = DeviceIdentity.currentDeviceId
        }
        if hasStoredTransactionsMetadata {
            self.transactionsRevision = defaults.integer(forKey: DefaultsKey.transactionsRevision)
            self.transactionsUpdatedAt = defaults.object(forKey: DefaultsKey.transactionsUpdatedAt) as? Date ?? Date(timeIntervalSince1970: 0)
            self.transactionsUpdatedByDeviceId = defaults.string(forKey: DefaultsKey.transactionsUpdatedByDeviceId) ?? DeviceIdentity.currentDeviceId
        } else if !initializedTransactions.isEmpty {
            self.transactionsRevision = 1
            self.transactionsUpdatedAt = Date()
            self.transactionsUpdatedByDeviceId = DeviceIdentity.currentDeviceId
        } else {
            self.transactionsRevision = 0
            self.transactionsUpdatedAt = Date(timeIntervalSince1970: 0)
            self.transactionsUpdatedByDeviceId = DeviceIdentity.currentDeviceId
        }

        normalizeDefaultNames()
        normalizeCategoryHierarchy()
        normalizeDefaultSelections()
        normalizeTransactionsAfterMetadataChange()
        persistAccounts()
        persistCategories()
        persistTransactions()
        persistMetadata()
        persistTransactionsMetadata()
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

    func saveTransaction(_ transaction: DraftTransaction) {
        let normalizedTransaction = normalizedTransactionAmounts(transaction)
        transactions.insert(normalizedTransaction, at: 0)
        transactions.sort(by: Self.transactionSort)
        lastDraft = transactions.first
        applyTransactionToAccountBalances(normalizedTransaction)
        persistAccounts()
        persistTransactions()
        persistLastDraft()
        markMetadataChanged()
        markTransactionsChanged()
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
        markMetadataChanged()
        markTransactionsChanged()
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
        markMetadataChanged()
        markTransactionsChanged()
        messageKey = "transactions.message.deleted"
        return true
    }

    func backupLedgerDataNow(configuration: SyncConfiguration, secrets: SyncSecrets) async -> Bool {
        guard configuration.backupEnabled else {
            messageKey = "bookkeeping.ledger.sync.error.backupDisabled"
            return false
        }

        do {
            try await syncService.backup(
                document: makeMetadataDocument(),
                configuration: configuration,
                secrets: secrets
            )
            try await transactionsSyncService.backup(
                document: makeTransactionsDocument(),
                configuration: configuration,
                secrets: secrets
            )
            messageKey = "bookkeeping.ledger.sync.backupSucceeded"
            return true
        } catch {
            messageKey = "bookkeeping.ledger.sync.error.backupFailed"
            return false
        }
    }

    func backupMetadataNow(configuration: SyncConfiguration, secrets: SyncSecrets) async -> Bool {
        guard configuration.backupEnabled else {
            messageKey = "bookkeeping.metadata.sync.error.backupDisabled"
            return false
        }

        do {
            try await syncService.backup(
                document: makeMetadataDocument(),
                configuration: configuration,
                secrets: secrets
            )
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
            guard let remoteDocument = try await syncService.importDocument(configuration: configuration, secrets: secrets) else {
                messageKey = "bookkeeping.metadata.sync.importNoRemoteMetadata"
                return true
            }

            applyRemoteMetadata(remoteDocument)
            messageKey = "bookkeeping.metadata.sync.importSucceeded"
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
            try await transactionsSyncService.backup(
                document: makeTransactionsDocument(),
                configuration: configuration,
                secrets: secrets
            )
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
            guard let remoteDocument = try await transactionsSyncService.importDocument(configuration: configuration, secrets: secrets) else {
                messageKey = "bookkeeping.transactions.sync.importNoRemoteTransactions"
                return true
            }

            applyRemoteTransactions(remoteDocument)
            messageKey = "bookkeeping.transactions.sync.importSucceeded"
            return true
        } catch {
            messageKey = "bookkeeping.transactions.sync.error.importFailed"
            return false
        }
    }

    func importIfRemoteTransactionsAreNewer(configuration: SyncConfiguration, secrets: SyncSecrets) async {
        guard configuration.backupEnabled else { return }

        do {
            guard let remoteDocument = try await transactionsSyncService.importDocument(configuration: configuration, secrets: secrets) else {
                return
            }

            guard remoteDocument.isNewer(than: makeTransactionsDocument()) else { return }

            applyRemoteTransactions(remoteDocument)
            messageKey = "bookkeeping.transactions.sync.importSucceeded"
        } catch {
            return
        }
    }

    func importIfRemoteMetadataIsNewer(configuration: SyncConfiguration, secrets: SyncSecrets) async {
        guard configuration.backupEnabled else { return }

        do {
            guard let remoteDocument = try await syncService.importDocument(configuration: configuration, secrets: secrets) else {
                return
            }

            guard remoteDocument.isNewer(than: makeMetadataDocument()) else { return }

            applyRemoteMetadata(remoteDocument)
            messageKey = "bookkeeping.metadata.sync.importSucceeded"
        } catch {
            return
        }
    }

    func addAccount(name: String, type: DraftAccountType, iconName: String, colorHex: String, balanceText: String, note: String) -> Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return false }
        guard let normalizedBalanceText = DraftAmountFormatter.normalizedAmountText(balanceText, allowNegative: false) else {
            messageKey = "management.account.error.invalidBalance"
            return false
        }

        accounts.append(DraftAccount(
            id: UUID().uuidString,
            name: trimmedName,
            isDefault: false,
            type: type,
            iconName: iconName,
            colorHex: colorHex,
            balanceText: normalizedBalanceText,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines)
        ))
        persistAccounts()
        markMetadataChanged()
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
        accounts[index].name = trimmedName
        accounts[index].type = type
        accounts[index].iconName = iconName
        accounts[index].colorHex = colorHex
        accounts[index].balanceText = normalizedBalanceText
        accounts[index].note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        persistAccounts()
        markMetadataChanged()
        messageKey = "management.account.saved"
        return true
    }

    func moveAccounts(from source: IndexSet, to destination: Int) {
        accounts.move(fromOffsets: source, toOffset: destination)
        persistAccounts()
        markMetadataChanged()
    }

    func setDefaultAccount(id: String) {
        guard accounts.contains(where: { $0.id == id && !$0.isArchived }) else { return }

        accounts = accounts.map { account in
            var updated = account
            updated.isDefault = !account.isArchived && account.id == id
            return updated
        }
        persistAccounts()
        markMetadataChanged()
        messageKey = "management.account.defaultSet"
    }

    func deleteAccount(id: String) -> Bool {
        let activeAccounts = accounts.filter { !$0.isArchived }
        guard activeAccounts.count > 1 else {
            messageKey = "management.account.error.lastItem"
            return false
        }

        if isAccountReferenced(id: id), let index = accounts.firstIndex(where: { $0.id == id }) {
            accounts[index].archivedAt = Date()
            accounts[index].isDefault = false
            messageKey = "management.account.archived"
        } else {
            accounts.removeAll { $0.id == id }
            messageKey = "management.account.deleted"
        }
        normalizeDefaultAccounts()
        persistAccounts()
        markMetadataChanged()
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

        categories.append(DraftCategory(
            id: UUID().uuidString,
            name: trimmedName,
            kind: kind,
            parentId: parentId,
            iconName: iconName,
            colorHex: colorHex
        ))
        persistCategories()
        markMetadataChanged()
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
        categories[index].name = trimmedName
        categories[index].parentId = parentId
        if parentId != nil {
            categories[index].isDefault = false
        }
        categories[index].iconName = iconName
        categories[index].colorHex = colorHex
        normalizeDefaultCategories(kind: kind)
        persistCategories()
        markMetadataChanged()
        messageKey = "management.category.saved"
        return true
    }

    func moveCategories(kind: DraftEntryKind, from source: IndexSet, to destination: Int) {
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
        markMetadataChanged()
    }

    func setDefaultCategory(id: String) {
        guard let selectedCategory = categories.first(where: { $0.id == id }) else { return }
        guard selectedCategory.parentId == nil else { return }

        categories = categories.map { category in
            var updated = category
            if category.kind == selectedCategory.kind {
                updated.isDefault = category.parentId == nil && category.id == id
            }
            return updated
        }
        persistCategories()
        markMetadataChanged()
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
        } else {
            categories.removeAll { deletedIds.contains($0.id) }
            messageKey = "management.category.deleted"
        }
        normalizeDefaultCategories(kind: category.kind)
        persistCategories()
        markMetadataChanged()
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

    private func makeMetadataDocument() -> BookkeepingMetadataSyncDocument {
        BookkeepingMetadataSyncDocument(
            revision: metadataRevision,
            updatedAt: metadataUpdatedAt,
            updatedByDeviceId: metadataUpdatedByDeviceId,
            accounts: accounts,
            categories: categories
        )
    }

    private func makeTransactionsDocument() -> BookkeepingTransactionsSyncDocument {
        BookkeepingTransactionsSyncDocument(
            revision: transactionsRevision,
            updatedAt: transactionsUpdatedAt,
            updatedByDeviceId: transactionsUpdatedByDeviceId,
            transactions: transactions
        )
    }

    private func applyRemoteMetadata(_ document: BookkeepingMetadataSyncDocument) {
        accounts = document.accounts.isEmpty ? Self.defaultAccounts : document.accounts
        categories = document.categories.isEmpty ? Self.defaultCategories : document.categories
        metadataRevision = document.revision
        metadataUpdatedAt = document.updatedAt
        metadataUpdatedByDeviceId = document.updatedByDeviceId

        normalizeDefaultNames()
        normalizeCategoryHierarchy()
        normalizeDefaultSelections()
        normalizeTransactionsAfterMetadataChange()
        persistAccounts()
        persistCategories()
        persistTransactions()
        persistLastDraft()
        persistMetadata()
    }

    private func applyRemoteTransactions(_ document: BookkeepingTransactionsSyncDocument) {
        transactions = document.transactions.sorted(by: Self.transactionSort)
        lastDraft = transactions.first
        transactionsRevision = document.revision
        transactionsUpdatedAt = document.updatedAt
        transactionsUpdatedByDeviceId = document.updatedByDeviceId

        normalizeTransactionsAfterMetadataChange()
        persistTransactions()
        persistLastDraft()
        persistTransactionsMetadata()
    }

    private func markMetadataChanged(at date: Date = Date()) {
        metadataRevision += 1
        metadataUpdatedAt = date
        metadataUpdatedByDeviceId = DeviceIdentity.currentDeviceId
        persistMetadata()
        localMetadataChangeToken += 1
    }

    private func markTransactionsChanged(at date: Date = Date()) {
        transactionsRevision += 1
        transactionsUpdatedAt = date
        transactionsUpdatedByDeviceId = DeviceIdentity.currentDeviceId
        persistTransactionsMetadata()
        localTransactionsChangeToken += 1
    }

    private func persistMetadata() {
        defaults.set(metadataRevision, forKey: DefaultsKey.metadataRevision)
        defaults.set(metadataUpdatedAt, forKey: DefaultsKey.metadataUpdatedAt)
        defaults.set(metadataUpdatedByDeviceId, forKey: DefaultsKey.metadataUpdatedByDeviceId)
    }

    private func persistTransactionsMetadata() {
        defaults.set(transactionsRevision, forKey: DefaultsKey.transactionsRevision)
        defaults.set(transactionsUpdatedAt, forKey: DefaultsKey.transactionsUpdatedAt)
        defaults.set(transactionsUpdatedByDeviceId, forKey: DefaultsKey.transactionsUpdatedByDeviceId)
    }

    private func normalizeTransactionsAfterMetadataChange() {
        lastDraft = transactions.first
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
        Self.save(accounts, forKey: DefaultsKey.accounts, to: defaults)
    }

    private func persistCategories() {
        Self.save(categories, forKey: DefaultsKey.categories, to: defaults)
    }

    private func persistTransactions() {
        Self.save(transactions, forKey: DefaultsKey.transactions, to: defaults)
    }

    private func persistLastDraft() {
        Self.save(lastDraft, forKey: DefaultsKey.lastDraft, to: defaults)
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

    private static func load<Value: Decodable>(_ type: Value.Type, forKey key: String, from defaults: UserDefaults) -> Value? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? decoder.decode(type, from: data)
    }

    private static func save<Value: Encodable>(_ value: Value, forKey key: String, to defaults: UserDefaults) {
        guard let data = try? encoder.encode(value) else { return }
        defaults.set(data, forKey: key)
    }

    private static func transactionSort(_ lhs: DraftTransaction, _ rhs: DraftTransaction) -> Bool {
        if lhs.date == rhs.date {
            return lhs.createdAt > rhs.createdAt
        }

        return lhs.date > rhs.date
    }

    private static func plainAmountText(from decimal: Decimal) -> String {
        let number = NSDecimalNumber(decimal: decimal)
        return plainAmountFormatter.string(from: number) ?? number.stringValue
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

    private static func fontAwesomeName(for legacyName: String) -> String {
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

        return mapping[legacyName] ?? legacyName
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
