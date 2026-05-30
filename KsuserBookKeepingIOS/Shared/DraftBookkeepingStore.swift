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

    init(
        id: String,
        name: String,
        isDefault: Bool,
        type: DraftAccountType = .cash,
        iconName: String = "wallet",
        colorHex: String = "#F6C343",
        balanceText: String = "0",
        note: String = ""
    ) {
        self.id = id
        self.name = name
        self.isDefault = isDefault
        self.type = type
        self.iconName = iconName
        self.colorHex = colorHex
        self.balanceText = balanceText
        self.note = note
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
    }
}

struct DraftCategory: Codable, Identifiable, Equatable {
    var id: String
    var name: String
    var kind: DraftEntryKind
    var iconName: String
    var colorHex: String

    init(
        id: String,
        name: String,
        kind: DraftEntryKind,
        iconName: String = "tag",
        colorHex: String = "#F6C343"
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.iconName = iconName
        self.colorHex = colorHex
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.name = try container.decode(String.self, forKey: .name)
        self.kind = try container.decode(DraftEntryKind.self, forKey: .kind)
        self.iconName = try container.decodeIfPresent(String.self, forKey: .iconName) ?? ""
        self.colorHex = try container.decodeIfPresent(String.self, forKey: .colorHex) ?? ""
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
    var categoryId: String?
    var accountId: String?
    var fromAccountId: String?
    var toAccountId: String?
    var date: Date
    var note: String
    var createdAt: Date
}

@MainActor
final class DraftBookkeepingStore: ObservableObject {
    @Published private(set) var accounts: [DraftAccount]
    @Published private(set) var categories: [DraftCategory]
    @Published private(set) var lastDraft: DraftTransaction?
    @Published private(set) var messageKey: String?

    private let defaults: UserDefaults

    private enum DefaultsKey {
        static let accounts = "draftBookkeeping.accounts"
        static let categories = "draftBookkeeping.categories"
        static let lastDraft = "draftBookkeeping.lastDraft"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.accounts = Self.load([DraftAccount].self, forKey: DefaultsKey.accounts, from: defaults) ?? Self.defaultAccounts
        self.categories = Self.load([DraftCategory].self, forKey: DefaultsKey.categories, from: defaults) ?? Self.defaultCategories
        self.lastDraft = Self.load(DraftTransaction.self, forKey: DefaultsKey.lastDraft, from: defaults)

        normalizeDefaultNames()
        persistAccounts()
        persistCategories()
    }

    func clearMessage() {
        messageKey = nil
    }

    func categories(for kind: DraftEntryKind) -> [DraftCategory] {
        categories.filter { $0.kind == kind }
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
        guard
            let id,
            let category = categories.first(where: { $0.id == id })
        else {
            return NSLocalizedString("draft.item.missing", comment: "")
        }

        return category.name
    }

    func saveDraft(_ draft: DraftTransaction) {
        lastDraft = draft
        persistLastDraft()
        messageKey = "record.draft.saved"
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
        messageKey = "management.account.saved"
        return true
    }

    func deleteAccount(id: String) -> Bool {
        guard accounts.count > 1 else {
            messageKey = "management.account.error.lastItem"
            return false
        }

        accounts.removeAll { $0.id == id }
        persistAccounts()
        normalizeLastDraftAfterAccountDeletion(id: id)
        messageKey = "management.account.deleted"
        return true
    }

    func addCategory(name: String, kind: DraftEntryKind, iconName: String, colorHex: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        categories.append(DraftCategory(
            id: UUID().uuidString,
            name: trimmedName,
            kind: kind,
            iconName: iconName,
            colorHex: colorHex
        ))
        persistCategories()
        messageKey = "management.category.saved"
    }

    func updateCategory(id: String, name: String, iconName: String, colorHex: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        guard let index = categories.firstIndex(where: { $0.id == id }) else { return }
        categories[index].name = trimmedName
        categories[index].iconName = iconName
        categories[index].colorHex = colorHex
        persistCategories()
        messageKey = "management.category.saved"
    }

    func deleteCategory(id: String) -> Bool {
        guard let category = categories.first(where: { $0.id == id }) else { return false }
        guard categories(for: category.kind).count > 1 else {
            messageKey = "management.category.error.lastItem"
            return false
        }

        categories.removeAll { $0.id == id }
        persistCategories()
        normalizeLastDraftAfterCategoryDeletion(id: id)
        messageKey = "management.category.deleted"
        return true
    }

    private func normalizeLastDraftAfterAccountDeletion(id: String) {
        guard var draft = lastDraft else { return }

        if draft.accountId == id {
            draft.accountId = nil
        }
        if draft.fromAccountId == id {
            draft.fromAccountId = nil
        }
        if draft.toAccountId == id {
            draft.toAccountId = nil
        }

        lastDraft = draft
        persistLastDraft()
    }

    private func normalizeLastDraftAfterCategoryDeletion(id: String) {
        guard var draft = lastDraft, draft.categoryId == id else { return }

        draft.categoryId = nil
        lastDraft = draft
        persistLastDraft()
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

    private func persistLastDraft() {
        Self.save(lastDraft, forKey: DefaultsKey.lastDraft, to: defaults)
    }

    private static func load<Value: Decodable>(_ type: Value.Type, forKey key: String, from defaults: UserDefaults) -> Value? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? decoder.decode(type, from: data)
    }

    private static func save<Value: Encodable>(_ value: Value, forKey key: String, to defaults: UserDefaults) {
        guard let data = try? encoder.encode(value) else { return }
        defaults.set(data, forKey: key)
    }

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
