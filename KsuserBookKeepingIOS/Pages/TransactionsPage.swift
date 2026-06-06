import MapKit
import SwiftUI
import UIKit

struct TransactionsPage: View {
    @EnvironmentObject private var draftStore: DraftBookkeepingStore
    @EnvironmentObject private var profileStore: ProfileStore
    @EnvironmentObject private var syncCoordinator: SyncCoordinator
    @State private var editingTransaction: DraftTransaction?
    @State private var deletingTransaction: DraftTransaction?
    @State private var dateFilter = TransactionDateFilter()
    @State private var selectedAccountId: String?
    @State private var selectedCategoryId: String?
    @State private var hasInitializedDateFilter = false
    @State private var isSelectionMode = false
    @State private var selectedTransactionIds = Set<String>()
    @State private var isSelectionFilterPresented = false
    @State private var isBatchEditorPresented = false

    private var filteredTransactions: [DraftTransaction] {
        draftStore.transactions.filter { transaction in
            guard dateFilter.contains(transaction.date) else {
                return false
            }

            if let selectedAccountId, !matchesAccount(transaction, accountId: selectedAccountId) {
                return false
            }

            if let selectedCategoryId, transaction.categoryId != selectedCategoryId {
                return false
            }

            return true
        }
    }

    private var groupedTransactions: [TransactionDayGroup] {
        let calendar = Calendar.current
        let groups = Dictionary(grouping: filteredTransactions) { transaction in
            calendar.startOfDay(for: transaction.date)
        }

        return groups
            .map { date, transactions in
                TransactionDayGroup(date: date, transactions: sortedTransactions(transactions))
            }
            .sorted { $0.date > $1.date }
    }

    private var hasActiveFilters: Bool {
        selectedAccountId != nil || selectedCategoryId != nil
    }

    private var filteredTransactionIds: Set<String> {
        Set(filteredTransactions.map(\.id))
    }

    private var areAllFilteredTransactionsSelected: Bool {
        !filteredTransactions.isEmpty && filteredTransactionIds.isSubset(of: selectedTransactionIds)
    }

    private var monthSelectionOptions: [TransactionMonthSelectionOption] {
        let calendar = Calendar.current
        let groupedTransactions = Dictionary(grouping: draftStore.transactions) { transaction in
            startOfMonth(for: transaction.date, calendar: calendar)
        }

        return groupedTransactions
            .map { monthStart, transactions in
                TransactionMonthSelectionOption(
                    monthStart: monthStart,
                    title: monthTitle(for: monthStart),
                    transactionIds: Set(transactions.map(\.id))
                )
            }
            .sorted { $0.monthStart > $1.monthStart }
    }

    private var categorySelectionOptions: [TransactionCategorySelectionOption] {
        categoryHierarchyItems.compactMap { item in
            let transactionIds = Set(
                draftStore.transactions
                    .filter { $0.categoryId == item.category.id }
                    .map(\.id)
            )

            guard !transactionIds.isEmpty else {
                return nil
            }

            return TransactionCategorySelectionOption(
                category: item.category,
                title: archivedAwareName(
                    draftStore.categoryDisplayName(for: item.category.id),
                    isArchived: item.category.isArchived
                ),
                subtitle: categorySelectionSubtitle(for: item.category, count: transactionIds.count),
                transactionIds: transactionIds,
                depth: item.depth
            )
        }
    }

    private var categoryHierarchyItems: [DraftCategoryHierarchyItem] {
        DraftEntryKind.allCases.flatMap { kind in
            let rootCategories = draftStore.categories
                .filter { $0.kind == kind && $0.parentId == nil }
                .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }

            return rootCategories.flatMap { hierarchyItems(from: $0, depth: 1, visitedIds: []) }
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if draftStore.transactions.isEmpty {
                    Section {
                        VStack(spacing: 16) {
                            Image(systemName: "list.bullet.rectangle")
                                .font(.system(size: 36, weight: .semibold))
                                .foregroundStyle(.tint)

                            Text("transactions.placeholder")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.vertical, 36)
                        .frame(maxWidth: .infinity)
                    }
                } else {
                    Section {
                        TransactionDateHeader(
                            dateFilter: $dateFilter,
                            onPrevious: { dateFilter.shift(by: -1) },
                            onNext: { dateFilter.shift(by: 1) }
                        )

                        TransactionFilterBar(
                            selectedAccountId: $selectedAccountId,
                            selectedCategoryId: $selectedCategoryId,
                            accounts: draftStore.accounts,
                            categories: draftStore.categories,
                            categoryDisplayName: { draftStore.categoryDisplayName(for: $0) },
                            hasActiveFilters: hasActiveFilters,
                            resetFilters: resetFilters
                        )

                        if isSelectionMode {
                            TransactionBatchSelectionBar(
                                selectedCount: selectedTransactionIds.count,
                                onSelectByFilter: {
                                    isSelectionFilterPresented = true
                                },
                                onClearSelection: {
                                    selectedTransactionIds = []
                                }
                            )
                        }
                    }
                    .listRowSeparator(.hidden)

                    if groupedTransactions.isEmpty {
                        Section {
                            TransactionEmptyFilteredView(hasActiveFilters: hasActiveFilters)
                                .padding(.vertical, 28)
                                .frame(maxWidth: .infinity)
                                .listRowSeparator(.hidden)
                        } footer: {
                            Text("transactions.footer.localOnly")
                        }
                    } else {
                        ForEach(groupedTransactions) { group in
                            Section {
                                ForEach(group.transactions) { transaction in
                                    TransactionSummaryCard(
                                        transaction: transaction,
                                        accountItem: accountItem(for: transaction),
                                        categoryItem: categoryItem(for: transaction),
                                        timeText: Self.timeText(for: transaction.date),
                                        isSelecting: isSelectionMode,
                                        isSelected: selectedTransactionIds.contains(transaction.id),
                                        onSelect: {
                                            toggleSelection(for: transaction)
                                        },
                                        onEdit: {
                                            editingTransaction = transaction
                                        }
                                    )
                                    .padding(.vertical, 6)
                                    .swipeActions(edge: .trailing) {
                                        if !isSelectionMode {
                                            Button(role: .destructive) {
                                                deletingTransaction = transaction
                                            } label: {
                                                Label("management.action.delete", systemImage: "trash")
                                            }
                                        }
                                    }
                                    .contextMenu {
                                        if !isSelectionMode {
                                            Button {
                                                editingTransaction = transaction
                                            } label: {
                                                Label("management.action.edit", systemImage: "pencil")
                                            }

                                            Button(role: .destructive) {
                                                deletingTransaction = transaction
                                            } label: {
                                                Label("management.action.delete", systemImage: "trash")
                                            }
                                        }
                                    }
                                }
                            } header: {
                                TransactionDayHeader(date: group.date)
                            } footer: {
                                if group.id == groupedTransactions.last?.id {
                                    Text("transactions.footer.localOnly")
                                }
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(Text("tab.transactions"))
            .toolbar {
                ToolbarItemGroup(placement: .topBarLeading) {
                    if !filteredTransactions.isEmpty {
                        Button {
                            if isSelectionMode {
                                isBatchEditorPresented = true
                            } else {
                                enterSelectionMode()
                            }
                        } label: {
                            Label("transactions.batch.edit", systemImage: "pencil.circle")
                        }
                        .disabled(isSelectionMode && selectedTransactionIds.isEmpty)
                    }
                }

                ToolbarItemGroup(placement: .topBarTrailing) {
                    if isSelectionMode {
                        if !filteredTransactions.isEmpty {
                            Button {
                                toggleSelectAllFiltered()
                            } label: {
                                Text(LocalizedStringKey(areAllFilteredTransactionsSelected ? "transactions.batch.deselectAll" : "transactions.batch.selectAll"))
                            }
                        }

                        Button("common.cancel") {
                            exitSelectionMode()
                        }
                    }
                }
            }
            .refreshable {
                _ = await syncCoordinator.refreshNow()
            }
            .onAppear {
                initializeDateFilterIfNeeded()
            }
            .onChange(of: draftStore.transactions) { _, _ in
                initializeDateFilterIfNeeded()
                pruneSelection()
            }
            .onChange(of: dateFilter) { _, _ in
                pruneSelection()
            }
            .onChange(of: selectedAccountId) { _, _ in
                pruneSelection()
            }
            .onChange(of: selectedCategoryId) { _, _ in
                pruneSelection()
            }
            .sheet(item: $editingTransaction) { transaction in
                TransactionEditorPage(transaction: transaction)
                    .environmentObject(draftStore)
                    .environmentObject(profileStore)
            }
            .sheet(isPresented: $isBatchEditorPresented) {
                TransactionBatchEditPage(
                    transactionIds: selectedTransactionIds,
                    selectedCount: selectedTransactionIds.count,
                    onSaved: {
                        exitSelectionMode()
                    }
                )
                .environmentObject(draftStore)
                .environmentObject(profileStore)
            }
            .sheet(isPresented: $isSelectionFilterPresented) {
                TransactionBatchSelectionFilterSheet(
                    selectedTransactionIds: $selectedTransactionIds,
                    currentFilteredIds: filteredTransactionIds,
                    monthOptions: monthSelectionOptions,
                    categoryOptions: categorySelectionOptions
                )
            }
            .confirmationDialog(
                Text("transactions.delete.title"),
                isPresented: Binding(
                    get: { deletingTransaction != nil },
                    set: { isPresented in
                        if !isPresented {
                            deletingTransaction = nil
                        }
                    }
                ),
                titleVisibility: .visible
            ) {
                Button("transactions.delete.confirm", role: .destructive) {
                    if let deletingTransaction {
                        draftStore.deleteTransaction(id: deletingTransaction.id)
                    }
                    deletingTransaction = nil
                }

                Button("common.cancel", role: .cancel) {
                    deletingTransaction = nil
                }
            } message: {
                Text("transactions.delete.message")
            }
        }
    }

    private func initializeDateFilterIfNeeded() {
        guard !hasInitializedDateFilter else { return }
        if let latestTransaction = draftStore.transactions.first {
            dateFilter.setReference(latestTransaction.date)
        }
        hasInitializedDateFilter = true
    }

    private func resetFilters() {
        selectedAccountId = nil
        selectedCategoryId = nil
    }

    private func enterSelectionMode() {
        isSelectionMode = true
        editingTransaction = nil
        deletingTransaction = nil
    }

    private func exitSelectionMode() {
        isSelectionMode = false
        selectedTransactionIds = []
        isSelectionFilterPresented = false
        isBatchEditorPresented = false
    }

    private func toggleSelection(for transaction: DraftTransaction) {
        if selectedTransactionIds.contains(transaction.id) {
            selectedTransactionIds.remove(transaction.id)
        } else {
            selectedTransactionIds.insert(transaction.id)
        }
    }

    private func toggleSelectAllFiltered() {
        if areAllFilteredTransactionsSelected {
            selectedTransactionIds.subtract(filteredTransactionIds)
        } else {
            selectedTransactionIds.formUnion(filteredTransactionIds)
        }
    }

    private func pruneSelection() {
        selectedTransactionIds = selectedTransactionIds.intersection(filteredTransactionIds)
        if selectedTransactionIds.isEmpty, filteredTransactions.isEmpty {
            isSelectionMode = false
        }
    }

    private func matchesAccount(_ transaction: DraftTransaction, accountId: String) -> Bool {
        switch transaction.kind {
        case .expense, .income:
            return transaction.accountId == accountId
        case .transfer:
            return transaction.fromAccountId == accountId || transaction.toAccountId == accountId
        }
    }

    private func sortedTransactions(_ transactions: [DraftTransaction]) -> [DraftTransaction] {
        transactions.sorted { lhs, rhs in
            if lhs.date == rhs.date {
                return lhs.createdAt > rhs.createdAt
            }
            return lhs.date > rhs.date
        }
    }

    private func startOfMonth(for date: Date, calendar: Calendar) -> Date {
        let components = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: components) ?? calendar.startOfDay(for: date)
    }

    private func monthTitle(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = AppLocalization.locale
        formatter.dateFormat = DateFormatter.dateFormat(fromTemplate: "yMMMM", options: 0, locale: AppLocalization.locale)
        return formatter.string(from: date)
    }

    private func categorySelectionSubtitle(for category: DraftCategory, count: Int) -> String {
        let kindTitle = AppLocalization.string(category.kind.localizationKey, comment: "")
        let countText = String(
            format: AppLocalization.string("transactions.batch.selectionFilters.countFormat", comment: ""),
            count
        )
        return "\(kindTitle) · \(countText)"
    }

    private func hierarchyItems(
        from category: DraftCategory,
        depth: Int,
        visitedIds: Set<String>
    ) -> [DraftCategoryHierarchyItem] {
        guard !visitedIds.contains(category.id) else { return [] }

        let nextVisitedIds = visitedIds.union([category.id])
        let children = draftStore.categories
            .filter { $0.parentId == category.id }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }

        return [DraftCategoryHierarchyItem(category: category, depth: depth)] + children.flatMap { child in
            hierarchyItems(from: child, depth: depth + 1, visitedIds: nextVisitedIds)
        }
    }

    private func accountItem(for id: String?) -> DraftVisualSummaryItem {
        guard
            let id,
            let account = draftStore.accounts.first(where: { $0.id == id })
        else {
            return DraftVisualSummaryItem(
                name: AppLocalization.string("draft.item.missing", comment: ""),
                iconName: "circle-question",
                colorHex: "#64748B"
            )
        }

        return DraftVisualSummaryItem(
            name: archivedAwareName(account.name, isArchived: account.isArchived),
            iconName: account.iconName,
            colorHex: account.colorHex
        )
    }

    private func categoryItem(for id: String?) -> DraftVisualSummaryItem {
        guard
            let id,
            let category = draftStore.categories.first(where: { $0.id == id })
        else {
            return DraftVisualSummaryItem(
                name: AppLocalization.string("draft.item.missing", comment: ""),
                iconName: "circle-question",
                colorHex: "#64748B"
            )
        }

        return DraftVisualSummaryItem(
            name: archivedAwareName(draftStore.categoryDisplayName(for: category.id), isArchived: category.isArchived),
            iconName: category.iconName,
            colorHex: category.colorHex
        )
    }

    private func archivedAwareName(_ name: String, isArchived: Bool) -> String {
        guard isArchived else { return name }
        return String(format: AppLocalization.string("draft.item.archivedFormat", comment: ""), name)
    }

    private func accountItem(for transaction: DraftTransaction) -> DraftVisualSummaryItem {
        switch transaction.kind {
        case .expense, .income:
            return accountItem(for: transaction.accountId)
        case .transfer:
            let fromAccount = accountItem(for: transaction.fromAccountId)
            let toAccount = accountItem(for: transaction.toAccountId)
            return DraftVisualSummaryItem(
                name: String(
                    format: AppLocalization.string("dashboard.transferAccountFormat", comment: ""),
                    fromAccount.name,
                    toAccount.name
                ),
                iconName: "right-left",
                colorHex: "#3B82F6"
            )
        }
    }

    private func categoryItem(for transaction: DraftTransaction) -> DraftVisualSummaryItem {
        switch transaction.kind {
        case .expense, .income:
            return categoryItem(for: transaction.categoryId)
        case .transfer:
            return DraftVisualSummaryItem(
                name: AppLocalization.string("record.kind.transfer", comment: ""),
                iconName: "right-left",
                colorHex: "#3B82F6"
            )
        }
    }

    private static func timeText(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = AppLocalization.locale
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

private struct TransactionDayGroup: Identifiable {
    let date: Date
    let transactions: [DraftTransaction]

    var id: Date { date }
}

private struct TransactionFilterBar: View {
    @Binding var selectedAccountId: String?
    @Binding var selectedCategoryId: String?
    let accounts: [DraftAccount]
    let categories: [DraftCategory]
    let categoryDisplayName: (String) -> String
    let hasActiveFilters: Bool
    let resetFilters: () -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                NavigationLink {
                    TransactionAccountFilterSelectionPage(
                        accounts: accounts,
                        selectedAccountId: $selectedAccountId
                    )
                } label: {
                    TransactionFilterPill(
                        title: accountTitle,
                        iconName: selectedAccount?.iconName,
                        colorHex: selectedAccount?.colorHex,
                        systemImage: "creditcard",
                        isActive: selectedAccountId != nil
                    )
                }
                .buttonStyle(.plain)

                NavigationLink {
                    TransactionCategoryFilterSelectionPage(
                        items: categoryHierarchyItems,
                        selectedCategoryId: $selectedCategoryId,
                        displayName: categoryDisplayName
                    )
                } label: {
                    TransactionFilterPill(
                        title: categoryTitle,
                        iconName: selectedCategory?.iconName,
                        colorHex: selectedCategory?.colorHex,
                        systemImage: "tag",
                        isActive: selectedCategoryId != nil
                    )
                }
                .buttonStyle(.plain)

                if hasActiveFilters {
                    Button(action: resetFilters) {
                        TransactionFilterPill(
                            title: AppLocalization.string("transactions.filter.reset", comment: ""),
                            systemImage: "xmark.circle",
                            isActive: false
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 1)
        }
    }

    private var accountTitle: String {
        guard let account = selectedAccount else {
            return AppLocalization.string("transactions.filter.allAccounts", comment: "")
        }

        return archivedAwareName(account.name, isArchived: account.isArchived)
    }

    private var categoryTitle: String {
        guard let category = selectedCategory else {
            return AppLocalization.string("transactions.filter.allCategories", comment: "")
        }

        return archivedAwareName(categoryDisplayName(category.id), isArchived: category.isArchived)
    }

    private var selectedAccount: DraftAccount? {
        guard let selectedAccountId else { return nil }
        return accounts.first(where: { $0.id == selectedAccountId })
    }

    private var selectedCategory: DraftCategory? {
        guard let selectedCategoryId else { return nil }
        return categories.first(where: { $0.id == selectedCategoryId })
    }

    private var categoryHierarchyItems: [DraftCategoryHierarchyItem] {
        DraftEntryKind.allCases.flatMap { kind in
            let rootCategories = categories
                .filter { $0.kind == kind && $0.parentId == nil }
                .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }

            return rootCategories.flatMap { hierarchyItems(from: $0, depth: 1, visitedIds: []) }
        }
    }

    private func hierarchyItems(
        from category: DraftCategory,
        depth: Int,
        visitedIds: Set<String>
    ) -> [DraftCategoryHierarchyItem] {
        guard !visitedIds.contains(category.id) else { return [] }

        let nextVisitedIds = visitedIds.union([category.id])
        let children = categories
            .filter { $0.parentId == category.id }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }

        return [DraftCategoryHierarchyItem(category: category, depth: depth)] + children.flatMap { child in
            hierarchyItems(from: child, depth: depth + 1, visitedIds: nextVisitedIds)
        }
    }

    private func archivedAwareName(_ name: String, isArchived: Bool) -> String {
        guard isArchived else { return name }
        return String(format: AppLocalization.string("draft.item.archivedFormat", comment: ""), name)
    }
}

private struct TransactionFilterPill: View {
    let title: String
    var iconName: String?
    var colorHex: String?
    let systemImage: String
    let isActive: Bool

    var body: some View {
        HStack(spacing: 7) {
            if let iconName, let colorHex {
                DraftVisualBadge(iconName: iconName, colorHex: colorHex, size: 22)
            } else {
                Image(systemName: systemImage)
                    .font(.caption.weight(.semibold))
            }

            Text(title)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
        }
            .foregroundStyle(isActive ? Color.accentColor : .primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(isActive ? Color.accentColor.opacity(0.14) : Color.secondary.opacity(0.12))
            )
    }
}

private struct TransactionAccountFilterSelectionPage: View {
    let accounts: [DraftAccount]
    @Binding var selectedAccountId: String?
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private var filteredAccounts: [DraftAccount] {
        let query = normalized(searchText)
        guard !query.isEmpty else { return accounts }

        return accounts.filter { account in
            normalized(account.name).localizedCaseInsensitiveContains(query)
                || normalized(account.typeTitle).localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        List {
            Button {
                selectedAccountId = nil
                dismiss()
            } label: {
                TransactionFilterSelectionRow(
                    title: AppLocalization.string("transactions.filter.allAccounts", comment: ""),
                    subtitle: "",
                    iconName: "credit-card",
                    colorHex: "#64748B",
                    isSelected: selectedAccountId == nil
                )
            }
            .buttonStyle(.plain)

            ForEach(filteredAccounts) { account in
                Button {
                    selectedAccountId = account.id
                    dismiss()
                } label: {
                    TransactionFilterSelectionRow(
                        title: archivedAwareName(account.name, isArchived: account.isArchived),
                        subtitle: account.filterSubtitle,
                        iconName: account.iconName,
                        colorHex: account.colorHex,
                        isSelected: selectedAccountId == account.id
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .navigationTitle(Text("transactions.filter.accounts.title"))
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: Text("transactions.filter.search.placeholder"))
    }

    private func normalized(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func archivedAwareName(_ name: String, isArchived: Bool) -> String {
        guard isArchived else { return name }
        return String(format: AppLocalization.string("draft.item.archivedFormat", comment: ""), name)
    }
}

private struct TransactionCategoryFilterSelectionPage: View {
    let items: [DraftCategoryHierarchyItem]
    @Binding var selectedCategoryId: String?
    let displayName: (String) -> String
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private var filteredItems: [DraftCategoryHierarchyItem] {
        let query = normalized(searchText)
        guard !query.isEmpty else { return items }

        return items.filter { item in
            let category = item.category
            return normalized(displayName(category.id)).localizedCaseInsensitiveContains(query)
                || normalized(category.name).localizedCaseInsensitiveContains(query)
                || AppLocalization.string(category.kind.localizationKey, comment: "").localizedCaseInsensitiveContains(query)
                || AppLocalization.string(levelTitleKey(for: item.depth), comment: "").localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        List {
            Button {
                selectedCategoryId = nil
                dismiss()
            } label: {
                TransactionFilterSelectionRow(
                    title: AppLocalization.string("transactions.filter.allCategories", comment: ""),
                    subtitle: "",
                    iconName: "tag",
                    colorHex: "#64748B",
                    isSelected: selectedCategoryId == nil
                )
            }
            .buttonStyle(.plain)

            ForEach(filteredItems) { item in
                let category = item.category

                Button {
                    selectedCategoryId = category.id
                    dismiss()
                } label: {
                    TransactionCategoryFilterSelectionRow(
                        item: item,
                        title: archivedAwareName(category.name, isArchived: category.isArchived),
                        iconName: category.iconName,
                        colorHex: category.colorHex,
                        isSelected: selectedCategoryId == category.id
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .navigationTitle(Text("transactions.filter.categories.title"))
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: Text("transactions.filter.search.placeholder"))
    }

    private func normalized(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func archivedAwareName(_ name: String, isArchived: Bool) -> String {
        guard isArchived else { return name }
        return String(format: AppLocalization.string("draft.item.archivedFormat", comment: ""), name)
    }

    private func levelTitleKey(for depth: Int) -> String {
        switch depth {
        case 2:
            return "management.category.level.second"
        case 3:
            return "management.category.level.third"
        default:
            return "management.category.level.first"
        }
    }
}

private struct TransactionFilterSelectionRow: View {
    let title: String
    let subtitle: String
    let iconName: String
    let colorHex: String
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            DraftVisualBadge(iconName: iconName, colorHex: colorHex)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if isSelected {
                Image(systemName: "checkmark")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.tint)
            }
        }
        .contentShape(Rectangle())
    }
}

private struct TransactionCategoryFilterSelectionRow: View {
    let item: DraftCategoryHierarchyItem
    let title: String
    let iconName: String
    let colorHex: String
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            Spacer()
                .frame(width: CGFloat(item.depth - 1) * 24)

            DraftVisualBadge(iconName: iconName, colorHex: colorHex)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                if item.depth > 1 {
                    Text(levelTitleKey(for: item.depth))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if isSelected {
                Image(systemName: "checkmark")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.tint)
            }
        }
        .contentShape(Rectangle())
    }

    private func levelTitleKey(for depth: Int) -> LocalizedStringKey {
        switch depth {
        case 2:
            return "management.category.level.second"
        case 3:
            return "management.category.level.third"
        default:
            return "management.category.level.first"
        }
    }
}

private extension DraftAccount {
    var typeTitle: String {
        AppLocalization.string(type.localizationKey, comment: "")
    }

    var filterSubtitle: String {
        String(
            format: AppLocalization.string("transactions.filter.accountBalanceFormat", comment: ""),
            typeTitle,
            DraftAmountFormatter.currencyText(from: balanceText)
        )
    }
}

private struct TransactionDayHeader: View {
    let date: Date

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(Self.dayText(for: date))
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.primary)

                Text(Self.weekdayText(for: date))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 44, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                Text(Self.fullDateText(for: date))
                    .font(.subheadline.weight(.semibold))
            }

            Spacer()
        }
    }

    private static func dayText(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = AppLocalization.locale
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }

    private static func weekdayText(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = AppLocalization.locale
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }

    private static func fullDateText(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = AppLocalization.locale
        formatter.dateFormat = DateFormatter.dateFormat(fromTemplate: "yMMMd", options: 0, locale: AppLocalization.locale)
        return formatter.string(from: date)
    }
}

private struct TransactionEmptyFilteredView: View {
    let hasActiveFilters: Bool

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: hasActiveFilters ? "line.3.horizontal.decrease.circle" : "calendar")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(.tint)

            Text(LocalizedStringKey(hasActiveFilters ? "transactions.empty.filtered" : "transactions.empty.month"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }
}

private struct TransactionBatchSelectionBar: View {
    let selectedCount: Int
    let onSelectByFilter: () -> Void
    let onClearSelection: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Label(
                String(
                    format: AppLocalization.string("transactions.batch.selectedCountFormat", comment: ""),
                    selectedCount
                ),
                systemImage: "checkmark.circle"
            )
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)

            Spacer(minLength: 8)

            Button(action: onSelectByFilter) {
                Label("transactions.batch.selectionFilters.title", systemImage: "line.3.horizontal.decrease.circle")
            }
            .font(.subheadline.weight(.semibold))
            .buttonStyle(.borderless)

            if selectedCount > 0 {
                Button(action: onClearSelection) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
                .accessibilityLabel(Text("transactions.batch.clearSelection"))
            }
        }
    }
}

private struct TransactionMonthSelectionOption: Identifiable, Equatable {
    let monthStart: Date
    let title: String
    let transactionIds: Set<String>

    var id: Date { monthStart }
}

private struct TransactionCategorySelectionOption: Identifiable, Equatable {
    let category: DraftCategory
    let title: String
    let subtitle: String
    let transactionIds: Set<String>
    let depth: Int

    var id: String { category.id }
}

private struct TransactionBatchSelectionFilterSheet: View {
    @Binding var selectedTransactionIds: Set<String>
    let currentFilteredIds: Set<String>
    let monthOptions: [TransactionMonthSelectionOption]
    let categoryOptions: [TransactionCategorySelectionOption]
    @Environment(\.dismiss) private var dismiss
    @State private var categorySearchText = ""

    private var filteredCategoryOptions: [TransactionCategorySelectionOption] {
        let query = categorySearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            return categoryOptions
        }

        return categoryOptions.filter { option in
            option.title.localizedCaseInsensitiveContains(query)
                || option.category.name.localizedCaseInsensitiveContains(query)
                || option.subtitle.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        addSelection(currentFilteredIds)
                    } label: {
                        TransactionSelectionFilterRow(
                            title: AppLocalization.string("transactions.batch.selectionFilters.current", comment: ""),
                            subtitle: countText(for: currentFilteredIds.count),
                            systemImage: "line.3.horizontal.decrease.circle",
                            selectedCount: selectedCount(in: currentFilteredIds)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(currentFilteredIds.isEmpty)
                } footer: {
                    Text("transactions.batch.selectionFilters.current.footer")
                }

                Section {
                    if monthOptions.isEmpty {
                        TransactionSelectionFilterEmptyRow(titleKey: "transactions.batch.selectionFilters.emptyMonths")
                    } else {
                        ForEach(monthOptions) { option in
                            Button {
                                addSelection(option.transactionIds)
                            } label: {
                                TransactionSelectionFilterRow(
                                    title: option.title,
                                    subtitle: countText(for: option.transactionIds.count),
                                    systemImage: "calendar",
                                    selectedCount: selectedCount(in: option.transactionIds)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } header: {
                    Text("transactions.batch.selectionFilters.months")
                }

                Section {
                    if filteredCategoryOptions.isEmpty {
                        TransactionSelectionFilterEmptyRow(titleKey: "transactions.batch.selectionFilters.emptyCategories")
                    } else {
                        ForEach(filteredCategoryOptions) { option in
                            Button {
                                addSelection(option.transactionIds)
                            } label: {
                                TransactionCategorySelectionFilterRow(
                                    option: option,
                                    selectedCount: selectedCount(in: option.transactionIds)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } header: {
                    Text("transactions.batch.selectionFilters.categories")
                }
            }
            .navigationTitle(Text("transactions.batch.selectionFilters.title"))
            .navigationBarTitleDisplayMode(.inline)
            .searchable(
                text: $categorySearchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: Text("transactions.filter.search.placeholder")
            )
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func addSelection(_ ids: Set<String>) {
        selectedTransactionIds.formUnion(ids)
    }

    private func selectedCount(in ids: Set<String>) -> Int {
        selectedTransactionIds.intersection(ids).count
    }

    private func countText(for count: Int) -> String {
        String(
            format: AppLocalization.string("transactions.batch.selectionFilters.countFormat", comment: ""),
            count
        )
    }
}

private struct TransactionSelectionFilterRow: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let selectedCount: Int

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(.tint)
                .frame(width: 32, height: 32)
                .background(Circle().fill(Color.accentColor.opacity(0.14)))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if selectedCount > 0 {
                Text(
                    String(
                        format: AppLocalization.string("transactions.batch.selectionFilters.selectedCountFormat", comment: ""),
                        selectedCount
                    )
                )
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tint)
            }
        }
        .contentShape(Rectangle())
    }
}

private struct TransactionCategorySelectionFilterRow: View {
    let option: TransactionCategorySelectionOption
    let selectedCount: Int

    var body: some View {
        HStack(spacing: 12) {
            Spacer()
                .frame(width: CGFloat(option.depth - 1) * 24)

            DraftVisualBadge(iconName: option.category.iconName, colorHex: option.category.colorHex)

            VStack(alignment: .leading, spacing: 3) {
                Text(option.title)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(option.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if selectedCount > 0 {
                Text(
                    String(
                        format: AppLocalization.string("transactions.batch.selectionFilters.selectedCountFormat", comment: ""),
                        selectedCount
                    )
                )
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tint)
            }
        }
        .contentShape(Rectangle())
    }
}

private struct TransactionSelectionFilterEmptyRow: View {
    let titleKey: LocalizedStringKey

    var body: some View {
        Text(titleKey)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 8)
    }
}

private struct TransactionSummaryCard: View {
    let transaction: DraftTransaction
    let accountItem: DraftVisualSummaryItem
    let categoryItem: DraftVisualSummaryItem
    let timeText: String
    let isSelecting: Bool
    let isSelected: Bool
    let onSelect: () -> Void
    let onEdit: () -> Void

    private var amountText: String {
        switch transaction.kind {
        case .expense:
            return "-\(DraftAmountFormatter.currencyText(from: transaction.amountText))"
        case .income:
            return "+\(DraftAmountFormatter.currencyText(from: transaction.amountText))"
        case .transfer:
            return DraftAmountFormatter.currencyText(from: transaction.amountText)
        }
    }

    private var amountColor: Color {
        switch transaction.kind {
        case .expense:
            return .red
        case .income:
            return .green
        case .transfer:
            return .primary
        }
    }

    var body: some View {
        Button(action: isSelecting ? onSelect : onEdit) {
            HStack(alignment: .center, spacing: 12) {
                if isSelecting {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                        .frame(width: 24)
                }

                DraftVisualBadge(iconName: categoryItem.iconName, colorHex: categoryItem.colorHex, size: 38)

                VStack(alignment: .leading, spacing: 5) {
                    Text(categoryItem.name)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    if !transaction.note.isEmpty {
                        Text(transaction.note)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    HStack(spacing: 5) {
                        Text(timeText)

                        Text("·")

                        Text(accountItem.name)

                        if let location = transaction.location {
                            Text("·")
                            Image(systemName: "location.fill")
                                .accessibilityLabel(Text(location.displayName))
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                }

                Spacer(minLength: 12)

                HStack(spacing: 8) {
                    Text(amountText)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(amountColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.68)

                    if !isSelecting {
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct TransactionLocationButton: View {
    let location: DraftLocation
    var font: Font = .body
    @State private var isMapPickerPresented = false

    var body: some View {
        Button {
            isMapPickerPresented = true
        } label: {
            Label(location.displayName, systemImage: "location.fill")
                .lineLimit(1)
                .font(font)
                .foregroundStyle(.tint)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            Text(
                String(
                    format: AppLocalization.string("transactions.location.openInMaps.accessibility", comment: ""),
                    location.displayName
                )
            )
        )
        .confirmationDialog(
            Text("transactions.location.mapPicker.title"),
            isPresented: $isMapPickerPresented,
            titleVisibility: .visible
        ) {
            Button("transactions.location.mapPicker.appleMaps") {
                location.openInAppleMaps()
            }

            Button("transactions.location.mapPicker.amap") {
                location.openInAmap()
            }

            Button("common.cancel", role: .cancel) {}
        } message: {
            Text(location.displayName)
        }
    }
}

private extension DraftLocation {
    func openInAppleMaps() {
        let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        guard CLLocationCoordinate2DIsValid(coordinate) else { return }

        let placemark = MKPlacemark(coordinate: coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = displayName.isEmpty ? address : displayName
        mapItem.openInMaps(
            launchOptions: [
                MKLaunchOptionsMapCenterKey: NSValue(mkCoordinate: coordinate),
                MKLaunchOptionsMapSpanKey: NSValue(
                    mkCoordinateSpan: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                )
            ]
        )
    }

    func openInAmap() {
        let coordinate = gcj02Coordinate
        let sourceApplication = "KKBookkeep".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "KKBookkeep"
        let pointName = mapPointName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "iosamap://viewMap?sourceApplication=\(sourceApplication)&poiname=\(pointName)&lat=\(coordinate.latitude)&lon=\(coordinate.longitude)&dev=0"

        guard let url = URL(string: urlString) else { return }
        UIApplication.shared.open(url)
    }

    var mapPointName: String {
        if !displayName.isEmpty {
            return displayName
        }
        if !address.isEmpty {
            return address
        }
        return coordinateText
    }

    var gcj02Coordinate: CLLocationCoordinate2D {
        let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        guard !Self.isOutsideChina(latitude: latitude, longitude: longitude) else {
            return coordinate
        }

        var dLat = Self.transformLatitude(longitude - 105.0, latitude - 35.0)
        var dLon = Self.transformLongitude(longitude - 105.0, latitude - 35.0)
        let radLat = latitude / 180.0 * .pi
        var magic = sin(radLat)
        magic = 1 - Self.ee * magic * magic
        let sqrtMagic = sqrt(magic)
        dLat = (dLat * 180.0) / ((Self.a * (1 - Self.ee)) / (magic * sqrtMagic) * .pi)
        dLon = (dLon * 180.0) / (Self.a / sqrtMagic * cos(radLat) * .pi)
        return CLLocationCoordinate2D(latitude: latitude + dLat, longitude: longitude + dLon)
    }

    static var a: Double { 6378245.0 }
    static var ee: Double { 0.00669342162296594323 }

    static func isOutsideChina(latitude: Double, longitude: Double) -> Bool {
        longitude < 72.004 || longitude > 137.8347 || latitude < 0.8293 || latitude > 55.8271
    }

    static func transformLatitude(_ x: Double, _ y: Double) -> Double {
        var result = -100.0 + 2.0 * x + 3.0 * y + 0.2 * y * y + 0.1 * x * y + 0.2 * sqrt(abs(x))
        result += (20.0 * sin(6.0 * x * .pi) + 20.0 * sin(2.0 * x * .pi)) * 2.0 / 3.0
        result += (20.0 * sin(y * .pi) + 40.0 * sin(y / 3.0 * .pi)) * 2.0 / 3.0
        result += (160.0 * sin(y / 12.0 * .pi) + 320.0 * sin(y * .pi / 30.0)) * 2.0 / 3.0
        return result
    }

    static func transformLongitude(_ x: Double, _ y: Double) -> Double {
        var result = 300.0 + x + 2.0 * y + 0.1 * x * x + 0.1 * x * y + 0.1 * sqrt(abs(x))
        result += (20.0 * sin(6.0 * x * .pi) + 20.0 * sin(2.0 * x * .pi)) * 2.0 / 3.0
        result += (20.0 * sin(x * .pi) + 40.0 * sin(x / 3.0 * .pi)) * 2.0 / 3.0
        result += (150.0 * sin(x / 12.0 * .pi) + 300.0 * sin(x / 30.0 * .pi)) * 2.0 / 3.0
        return result
    }
}

private struct DraftVisualSummaryItem {
    let name: String
    let iconName: String
    let colorHex: String
}

private struct TransactionVisualSelectionItem: Identifiable, Equatable {
    let id: String
    let name: String
    let iconName: String
    let colorHex: String
    var subtitle: String = ""
    var depth: Int = 1
}

private struct TransactionVisualSelectionRow: View {
    let titleKey: LocalizedStringKey
    let item: TransactionVisualSelectionItem

    var body: some View {
        HStack(spacing: 12) {
            Text(titleKey)
                .foregroundStyle(.primary)

            Spacer(minLength: 16)

            VStack(alignment: .trailing, spacing: 3) {
                HStack(spacing: 8) {
                    DraftVisualBadge(iconName: item.iconName, colorHex: item.colorHex, size: 24)

                    Text(item.name)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if !item.subtitle.isEmpty {
                    Text(item.subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: 220, alignment: .trailing)
        }
    }
}

private struct TransactionVisualSelectionPage: View {
    let titleKey: LocalizedStringKey
    let items: [TransactionVisualSelectionItem]
    @Binding var selectedId: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List(items) { item in
            Button {
                selectedId = item.id
                dismiss()
            } label: {
                HStack(spacing: 12) {
                    Spacer()
                        .frame(width: CGFloat(item.depth - 1) * 24)

                    DraftVisualBadge(iconName: item.iconName, colorHex: item.colorHex)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(item.name)
                            .foregroundStyle(.primary)

                        if !item.subtitle.isEmpty {
                            Text(item.subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    if selectedId == item.id {
                        Image(systemName: "checkmark")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.tint)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .navigationTitle(Text(titleKey))
    }
}

private struct TransactionBatchEditPage: View {
    @EnvironmentObject private var draftStore: DraftBookkeepingStore
    @EnvironmentObject private var profileStore: ProfileStore
    @Environment(\.dismiss) private var dismiss
    @StateObject private var locationProvider = CurrentLocationProvider()

    let transactionIds: Set<String>
    let selectedCount: Int
    let onSaved: () -> Void

    @State private var shouldEditAmount = false
    @State private var amountText = ""
    @State private var shouldEditTime = false
    @State private var time = Date()
    @State private var shouldEditNote = false
    @State private var note = ""
    @State private var locationChange = TransactionBatchLocationChange.unchanged
    @State private var capturedLocation: DraftLocation?
    @State private var isLocating = false
    @State private var locationCaptureToken = 0
    @State private var locationMessageKey: String?
    @State private var errorKey: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("transactions.batch.selected") {
                        Text(
                            String(
                                format: AppLocalization.string("transactions.batch.selectedCountFormat", comment: ""),
                                selectedCount
                            )
                        )
                    }
                }

                Section {
                    Toggle("transactions.batch.field.amount", isOn: $shouldEditAmount)

                    if shouldEditAmount {
                        RecordAmountInputRow(
                            placeholderKey: "record.amount.placeholder",
                            amountText: $amountText,
                            currencySymbol: profileStore.profile.currency.symbol,
                            tint: .accentColor
                        )
                    }

                    Toggle("transactions.batch.field.time", isOn: $shouldEditTime)

                    if shouldEditTime {
                        DatePicker("transactions.batch.time", selection: $time, displayedComponents: [.hourAndMinute])
                    }

                    Toggle("transactions.batch.field.note", isOn: $shouldEditNote)

                    if shouldEditNote {
                        TextField("record.note.placeholder", text: $note, axis: .vertical)
                            .lineLimit(2...4)
                    }
                } header: {
                    Text("transactions.batch.section.fields")
                }

                Section {
                    Picker("transactions.batch.location", selection: $locationChange) {
                        ForEach(TransactionBatchLocationChange.allCases) { change in
                            Text(change.titleKey).tag(change)
                        }
                    }

                    switch locationChange {
                    case .unchanged:
                        EmptyView()
                    case .current:
                        currentLocationRow
                    case .clear:
                        Label("transactions.batch.location.clear.message", systemImage: "location.slash")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("transactions.batch.section.location")
                }

                if let errorKey {
                    Section {
                        Text(LocalizedStringKey(errorKey))
                            .font(.subheadline)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(Text("transactions.batch.edit.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        save()
                    } label: {
                        Label("common.save", systemImage: "checkmark.circle.fill")
                    }
                }
            }
            .onChange(of: locationChange) { _, newValue in
                errorKey = nil
                if newValue == .current, capturedLocation == nil {
                    captureLocation()
                }
            }
        }
    }

    @ViewBuilder
    private var currentLocationRow: some View {
        if let capturedLocation {
            VStack(alignment: .leading, spacing: 8) {
                Label {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(capturedLocation.displayName)
                            .foregroundStyle(.primary)

                        Text(capturedLocation.coordinateText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "location.fill")
                        .foregroundStyle(.tint)
                }

                Button {
                    captureLocation()
                } label: {
                    Label("transactions.batch.location.refresh", systemImage: "location")
                }
                .font(.subheadline)
                .disabled(isLocating)
            }
        } else {
            Button {
                captureLocation()
            } label: {
                HStack {
                    Label("record.location.capture", systemImage: "location")

                    Spacer()

                    if isLocating {
                        ProgressView()
                    }
                }
            }
            .disabled(isLocating)
        }

        if let locationMessageKey {
            Text(LocalizedStringKey(locationMessageKey))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func captureLocation() {
        guard !isLocating else { return }

        locationCaptureToken += 1
        let currentLocationCaptureToken = locationCaptureToken
        isLocating = true
        locationMessageKey = "record.location.locating"

        Task {
            do {
                let location = try await locationProvider.captureLocation()
                guard locationCaptureToken == currentLocationCaptureToken else { return }
                capturedLocation = location
                locationMessageKey = nil
            } catch CurrentLocationProvider.ProviderError.denied {
                guard locationCaptureToken == currentLocationCaptureToken else { return }
                locationMessageKey = "record.location.error.denied"
            } catch {
                guard locationCaptureToken == currentLocationCaptureToken else { return }
                locationMessageKey = "record.location.error.unavailable"
            }

            guard locationCaptureToken == currentLocationCaptureToken else { return }
            isLocating = false
        }
    }

    private func save() {
        draftStore.clearMessage()

        guard shouldEditAmount || shouldEditTime || shouldEditNote || locationChange != .unchanged else {
            errorKey = "transactions.batch.error.noFields"
            return
        }

        let amount: String?
        if shouldEditAmount {
            guard let normalizedAmount = normalizedPositiveAmountText(amountText) else {
                errorKey = "record.error.invalidAmount"
                return
            }
            amount = normalizedAmount
        } else {
            amount = nil
        }

        let locationEdit: DraftTransactionBatchEdit.LocationChange
        switch locationChange {
        case .unchanged:
            locationEdit = .unchanged
        case .current:
            guard let capturedLocation else {
                errorKey = "transactions.batch.error.locationRequired"
                return
            }
            locationEdit = .set(capturedLocation)
        case .clear:
            locationEdit = .clear
        }

        let edit = DraftTransactionBatchEdit(
            amountText: amount,
            timeComponents: shouldEditTime ? Calendar.current.dateComponents([.hour, .minute, .second], from: time) : nil,
            note: shouldEditNote ? note : nil,
            locationChange: locationEdit
        )

        guard draftStore.updateTransactions(ids: transactionIds, edit: edit) > 0 else {
            errorKey = "transactions.batch.error.noChanges"
            return
        }

        onSaved()
        dismiss()
    }

    private func normalizedPositiveAmountText(_ text: String) -> String? {
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
}

private enum TransactionBatchLocationChange: String, CaseIterable, Identifiable, Hashable {
    case unchanged
    case current
    case clear

    var id: String { rawValue }

    var titleKey: LocalizedStringKey {
        switch self {
        case .unchanged:
            return "transactions.batch.location.unchanged"
        case .current:
            return "transactions.batch.location.current"
        case .clear:
            return "transactions.batch.location.clear"
        }
    }
}

private struct TransactionEditorPage: View {
    @EnvironmentObject private var draftStore: DraftBookkeepingStore
    @EnvironmentObject private var profileStore: ProfileStore
    @Environment(\.dismiss) private var dismiss

    let transaction: DraftTransaction

    @State private var amountText: String
    @State private var transferInAmountText: String
    @State private var selectedCategoryId: String
    @State private var selectedAccountId: String
    @State private var selectedFromAccountId: String
    @State private var selectedToAccountId: String
    @State private var date: Date
    @State private var note: String
    @State private var errorKey: String?

    init(transaction: DraftTransaction) {
        self.transaction = transaction
        _amountText = State(initialValue: transaction.amountText)
        _transferInAmountText = State(initialValue: transaction.transferInAmountText ?? transaction.amountText)
        _selectedCategoryId = State(initialValue: transaction.categoryId ?? "")
        _selectedAccountId = State(initialValue: transaction.accountId ?? "")
        _selectedFromAccountId = State(initialValue: transaction.fromAccountId ?? "")
        _selectedToAccountId = State(initialValue: transaction.toAccountId ?? "")
        _date = State(initialValue: transaction.date)
        _note = State(initialValue: transaction.note)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("transactions.edit.kind") {
                        Text(transaction.kind.titleKey)
                    }
                }

                if transaction.kind == .transfer {
                    Section {
                        RecordAmountInputRow(
                            placeholderKey: "record.transferOutAmount.placeholder",
                            amountText: $amountText,
                            currencySymbol: profileStore.profile.currency.symbol,
                            tint: amountTint
                        )

                        RecordAmountInputRow(
                            placeholderKey: "record.transferInAmount.placeholder",
                            amountText: $transferInAmountText,
                            currencySymbol: profileStore.profile.currency.symbol,
                            tint: amountTint
                        )
                    } header: {
                        Text("record.section.transferAmount")
                    }

                    Section {
                        NavigationLink {
                            TransactionVisualSelectionPage(
                                titleKey: "record.fromAccount",
                                items: accountSelectionItems,
                                selectedId: $selectedFromAccountId
                            )
                        } label: {
                            TransactionVisualSelectionRow(
                                titleKey: "record.fromAccount",
                                item: accountSelectionItem(for: selectedFromAccountId)
                            )
                        }

                        NavigationLink {
                            TransactionVisualSelectionPage(
                                titleKey: "record.toAccount",
                                items: accountSelectionItems,
                                selectedId: $selectedToAccountId
                            )
                        } label: {
                            TransactionVisualSelectionRow(
                                titleKey: "record.toAccount",
                                item: accountSelectionItem(for: selectedToAccountId)
                            )
                        }
                    } header: {
                        Text("record.section.transfer")
                    }
                } else {
                    Section {
                        RecordAmountInputRow(
                            placeholderKey: "record.amount.placeholder",
                            amountText: $amountText,
                            currencySymbol: profileStore.profile.currency.symbol,
                            tint: amountTint
                        )
                    } header: {
                        Text("record.section.amount")
                    }

                    Section {
                        NavigationLink {
                            TransactionVisualSelectionPage(
                                titleKey: "record.category",
                                items: categorySelectionItems(for: transaction.kind),
                                selectedId: $selectedCategoryId
                            )
                        } label: {
                            TransactionVisualSelectionRow(
                                titleKey: "record.category",
                                item: categorySelectionItem(for: selectedCategoryId)
                            )
                        }

                        NavigationLink {
                            TransactionVisualSelectionPage(
                                titleKey: "record.account",
                                items: accountSelectionItems,
                                selectedId: $selectedAccountId
                            )
                        } label: {
                            TransactionVisualSelectionRow(
                                titleKey: "record.account",
                                item: accountSelectionItem(for: selectedAccountId)
                            )
                        }
                    } header: {
                        Text("record.section.bookkeeping")
                    }
                }

                Section {
                    DatePicker("record.dateTime", selection: $date, displayedComponents: [.date, .hourAndMinute])

                    if let location = transaction.location {
                        TransactionLocationButton(location: location)
                    }

                    TextField("record.note.placeholder", text: $note, axis: .vertical)
                        .lineLimit(2...4)
                } header: {
                    Text("record.section.detail")
                }

                if let errorKey {
                    Section {
                        Text(LocalizedStringKey(errorKey))
                            .font(.subheadline)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(Text("transactions.edit.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        save()
                    } label: {
                        Label("common.save", systemImage: "checkmark.circle.fill")
                    }
                }
            }
            .onAppear {
                normalizeSelections()
            }
            .onChange(of: amountText) { oldValue, newValue in
                guard transaction.kind == .transfer else { return }
                if transferInAmountText.isEmpty || transferInAmountText == oldValue {
                    transferInAmountText = newValue
                }
            }
            .onChange(of: draftStore.accounts) { _, _ in
                normalizeSelections()
            }
            .onChange(of: draftStore.categories) { _, _ in
                normalizeSelections()
            }
        }
    }

    private var amountTint: Color {
        switch transaction.kind {
        case .expense:
            return .red
        case .income:
            return .green
        case .transfer:
            return .primary
        }
    }

    private func save() {
        draftStore.clearMessage()

        guard let normalizedAmount = normalizedPositiveAmountText(amountText) else {
            errorKey = "record.error.invalidAmount"
            return
        }

        let normalizedTransferInAmount: String?
        if transaction.kind == .transfer {
            guard let amount = normalizedPositiveAmountText(transferInAmountText) else {
                errorKey = "record.error.invalidTransferInAmount"
                return
            }
            normalizedTransferInAmount = amount
        } else {
            normalizedTransferInAmount = nil
        }

        switch transaction.kind {
        case .expense, .income:
            guard !selectedCategoryId.isEmpty else {
                errorKey = "record.error.categoryRequired"
                return
            }

            guard !selectedAccountId.isEmpty else {
                errorKey = "record.error.accountRequired"
                return
            }
        case .transfer:
            guard !selectedFromAccountId.isEmpty, !selectedToAccountId.isEmpty else {
                errorKey = "record.error.accountRequired"
                return
            }

            guard selectedFromAccountId != selectedToAccountId else {
                errorKey = "record.error.sameTransferAccount"
                return
            }
        }

        let updatedTransaction = DraftTransaction(
            id: transaction.id,
            kind: transaction.kind,
            amountText: normalizedAmount,
            transferInAmountText: normalizedTransferInAmount,
            categoryId: transaction.kind == .transfer ? nil : selectedCategoryId,
            accountId: transaction.kind == .transfer ? nil : selectedAccountId,
            fromAccountId: transaction.kind == .transfer ? selectedFromAccountId : nil,
            toAccountId: transaction.kind == .transfer ? selectedToAccountId : nil,
            date: date,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines),
            location: transaction.location,
            createdAt: transaction.createdAt
        )

        if draftStore.updateTransaction(updatedTransaction) {
            dismiss()
        }
    }

    private func normalizeSelections() {
        let accounts = draftStore.accounts.filter { !$0.isArchived }
        if !draftStore.accounts.contains(where: { $0.id == selectedAccountId }) {
            selectedAccountId = defaultAccountId(in: accounts)
        }
        if !draftStore.accounts.contains(where: { $0.id == selectedFromAccountId }) {
            selectedFromAccountId = defaultAccountId(in: accounts)
        }
        if !draftStore.accounts.contains(where: { $0.id == selectedToAccountId }) {
            selectedToAccountId = defaultTransferDestinationAccountId(in: accounts)
        }

        let categories = draftStore.categories(for: transaction.kind)
        let selectedCategoryExists = draftStore.categories.contains { category in
            category.id == selectedCategoryId && category.kind == transaction.kind
        }
        if transaction.kind != .transfer, !selectedCategoryExists, !categories.contains(where: { $0.id == selectedCategoryId }) {
            selectedCategoryId = defaultCategoryId(in: categories)
        }
    }

    private var accountSelectionItems: [TransactionVisualSelectionItem] {
        draftStore.accounts.filter { !$0.isArchived }.map { account in
            TransactionVisualSelectionItem(
                id: account.id,
                name: account.name,
                iconName: account.iconName,
                colorHex: account.colorHex,
                subtitle: draftStore.accountBalanceSummary(for: account.id)
            )
        }
    }

    private func categorySelectionItems(for kind: DraftEntryKind) -> [TransactionVisualSelectionItem] {
        draftStore.categoryHierarchyItems(for: kind).map { item in
            let category = item.category

            return TransactionVisualSelectionItem(
                id: category.id,
                name: category.name,
                iconName: category.iconName,
                colorHex: category.colorHex,
                subtitle: draftStore.categoryTodaySummary(for: category.id),
                depth: item.depth
            )
        }
    }

    private func accountSelectionItem(for id: String) -> TransactionVisualSelectionItem {
        if let item = accountSelectionItems.first(where: { $0.id == id }) {
            return item
        }
        guard let account = draftStore.accounts.first(where: { $0.id == id }) else {
            return Self.unselectedSelectionItem
        }
        return TransactionVisualSelectionItem(
            id: account.id,
            name: archivedAwareName(account.name, isArchived: account.isArchived),
            iconName: account.iconName,
            colorHex: account.colorHex,
            subtitle: draftStore.accountBalanceSummary(for: account.id)
        )
    }

    private func categorySelectionItem(for id: String) -> TransactionVisualSelectionItem {
        guard let category = draftStore.categories.first(where: { $0.id == id }) else {
            return Self.unselectedSelectionItem
        }

        return TransactionVisualSelectionItem(
            id: category.id,
            name: archivedAwareName(draftStore.categoryDisplayName(for: category.id), isArchived: category.isArchived),
            iconName: category.iconName,
            colorHex: category.colorHex,
            subtitle: draftStore.categoryTodaySummary(for: category.id)
        )
    }

    private static var unselectedSelectionItem: TransactionVisualSelectionItem {
        TransactionVisualSelectionItem(
            id: "",
            name: AppLocalization.string("record.picker.unselected", comment: ""),
            iconName: "circle-question",
            colorHex: "#64748B",
            subtitle: "",
            depth: 1
        )
    }

    private func archivedAwareName(_ name: String, isArchived: Bool) -> String {
        guard isArchived else { return name }
        return String(format: AppLocalization.string("draft.item.archivedFormat", comment: ""), name)
    }

    private func defaultAccountId(in accounts: [DraftAccount]) -> String {
        accounts.first { $0.isDefault }?.id ?? accounts.first?.id ?? ""
    }

    private func defaultTransferDestinationAccountId(in accounts: [DraftAccount]) -> String {
        let defaultId = defaultAccountId(in: accounts)
        return accounts.first { $0.id != defaultId }?.id ?? defaultId
    }

    private func defaultCategoryId(in categories: [DraftCategory]) -> String {
        categories.first { $0.isDefault }?.id ?? categories.first?.id ?? ""
    }

    private func isPositiveAmount(_ text: String) -> Bool {
        normalizedPositiveAmountText(text) != nil
    }

    private func normalizedPositiveAmountText(_ text: String) -> String? {
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
}

#Preview {
    TransactionsPage()
        .environmentObject(DraftBookkeepingStore())
        .environmentObject(ProfileStore())
        .environmentObject(SyncCoordinator())
}
