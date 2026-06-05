import SwiftUI

struct BudgetManagementPage: View {
    @EnvironmentObject private var draftStore: DraftBookkeepingStore
    @EnvironmentObject private var profileStore: ProfileStore
    @State private var editingBudget: DraftBudget?
    @State private var deletingBudget: DraftBudget?
    @State private var draft = BudgetEditorDraft.empty
    @State private var isEditorPresented = false

    var body: some View {
        Form {
            Section {
                Button {
                    beginAdding()
                } label: {
                    Label("budgets.add", systemImage: "plus.circle.fill")
                }
            }

            if let messageKey = draftStore.messageKey {
                Section {
                    Text(LocalizedStringKey(messageKey))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                if draftStore.budgets.isEmpty {
                    ContentUnavailableView(
                        "budgets.empty.title",
                        systemImage: "chart.pie.fill",
                        description: Text("budgets.empty.subtitle")
                    )
                    .padding(.vertical, 18)
                } else {
                    ForEach(draftStore.budgets) { budget in
                        BudgetRow(
                            usage: draftStore.budgetUsage(for: budget),
                            title: draftStore.budgetDisplayName(budget),
                            scopeTitleKey: budget.scope.titleKey,
                            isEnabled: budget.isEnabled,
                            onEdit: {
                                beginEditing(budget)
                            }
                        )
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                deletingBudget = budget
                            } label: {
                                Label("management.action.delete", systemImage: "trash")
                            }
                            .tint(.red)

                            Button {
                                beginEditing(budget)
                            } label: {
                                Label("management.action.edit", systemImage: "pencil")
                            }
                            .tint(.accentColor)
                        }
                    }
                }
            } header: {
                Text("budgets.section")
            } footer: {
                Text("budgets.footer")
            }
        }
        .navigationTitle(Text("budgets.title"))
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                AppBackButton()
            }
        }
        .sheet(isPresented: $isEditorPresented) {
            BudgetEditorSheet(
                isEditing: editingBudget != nil,
                draft: $draft,
                accountItems: accountSelectionItems,
                categoryItems: categorySelectionItems,
                currencySymbol: profileStore.profile.currency.symbol,
                onScopeChange: normalizeDraftTarget,
                onCancel: {
                    isEditorPresented = false
                },
                onSave: {
                    saveBudget()
                }
            )
        }
        .confirmationDialog(
            Text("budgets.delete.confirm.title"),
            isPresented: Binding(
                get: { deletingBudget != nil },
                set: { isPresented in
                    if !isPresented {
                        deletingBudget = nil
                    }
                }
            ),
            titleVisibility: .visible
        ) {
            Button("management.action.delete", role: .destructive) {
                deletePendingBudget()
            }

            Button("common.cancel", role: .cancel) {
                deletingBudget = nil
            }
        } message: {
            Text("budgets.delete.confirm.message")
        }
    }

    private func beginAdding() {
        editingBudget = nil
        draft = .empty
        normalizeDraftTarget()
        isEditorPresented = true
    }

    private func beginEditing(_ budget: DraftBudget) {
        editingBudget = budget
        draft = BudgetEditorDraft(budget: budget)
        normalizeDraftTarget()
        isEditorPresented = true
    }

    private func saveBudget() {
        if let editingBudget {
            if draftStore.updateBudget(
                id: editingBudget.id,
                name: draft.name,
                scope: draft.scope,
                targetId: draft.resolvedTargetId,
                amountText: draft.amountText,
                isEnabled: draft.isEnabled
            ) {
                isEditorPresented = false
            }
        } else if draftStore.addBudget(
            name: draft.name,
            scope: draft.scope,
            targetId: draft.resolvedTargetId,
            amountText: draft.amountText,
            isEnabled: draft.isEnabled
        ) {
            isEditorPresented = false
        }
    }

    private func deletePendingBudget() {
        guard let deletingBudget else { return }

        _ = draftStore.deleteBudget(id: deletingBudget.id)
        self.deletingBudget = nil
    }

    private func normalizeDraftTarget() {
        switch draft.scope {
        case .overall:
            draft.categoryId = ""
            draft.accountId = ""
        case .category:
            if !categorySelectionItems.contains(where: { $0.id == draft.categoryId }) {
                draft.categoryId = categorySelectionItems.first?.id ?? ""
            }
        case .account:
            if !accountSelectionItems.contains(where: { $0.id == draft.accountId }) {
                draft.accountId = accountSelectionItems.first?.id ?? ""
            }
        }
    }

    private var accountSelectionItems: [BudgetSelectionItem] {
        draftStore.accounts.filter { !$0.isArchived }.map { account in
            BudgetSelectionItem(
                id: account.id,
                name: account.name,
                iconName: account.iconName,
                colorHex: account.colorHex,
                subtitle: draftStore.accountBalanceSummary(for: account.id)
            )
        }
    }

    private var categorySelectionItems: [BudgetSelectionItem] {
        draftStore.categoryHierarchyItems(for: .expense).map { item in
            BudgetSelectionItem(
                id: item.category.id,
                name: item.category.name,
                iconName: item.category.iconName,
                colorHex: item.category.colorHex,
                subtitle: draftStore.categoryTodaySummary(for: item.category.id),
                depth: item.depth
            )
        }
    }
}

private struct BudgetRow: View {
    let usage: DraftBudgetUsage
    let title: String
    let scopeTitleKey: LocalizedStringKey
    let isEnabled: Bool
    let onEdit: () -> Void

    private var spentText: String {
        DraftAmountFormatter.currencyText(from: usage.spentText)
    }

    private var limitText: String {
        DraftAmountFormatter.currencyText(from: usage.limitText)
    }

    private var tint: Color {
        if !isEnabled {
            return .secondary
        }
        return usage.isOverLimit ? .red : .accentColor
    }

    var body: some View {
        Button(action: onEdit) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text(title)
                                .font(.headline)
                                .foregroundStyle(.primary)
                                .lineLimit(1)

                            if !isEnabled {
                                Text("budgets.disabled.badge")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.secondary.opacity(0.12), in: Capsule())
                            }
                        }

                        Text(scopeTitleKey)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 12)

                    Text(String(format: NSLocalizedString("budgets.progress.percentFormat", comment: ""), usage.percentUsed * 100))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(tint)
                        .lineLimit(1)
                }

                ProgressView(value: min(max(usage.percentUsed, 0), 1))
                    .tint(tint)

                HStack {
                    Text(String(format: NSLocalizedString("budgets.progress.spentFormat", comment: ""), spentText, limitText))
                    Spacer()
                    Text(remainingText)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var remainingText: String {
        let amount = DraftAmountFormatter.currencyText(from: usage.remainingText)
        if usage.isOverLimit {
            return String(format: NSLocalizedString("budgets.progress.overFormat", comment: ""), amount.replacingOccurrences(of: "-", with: ""))
        }

        return String(format: NSLocalizedString("budgets.progress.remainingFormat", comment: ""), amount)
    }
}

private struct BudgetEditorDraft {
    var name: String
    var scope: DraftBudgetScope
    var categoryId: String
    var accountId: String
    var amountText: String
    var isEnabled: Bool

    static let empty = BudgetEditorDraft(
        name: "",
        scope: .overall,
        categoryId: "",
        accountId: "",
        amountText: "",
        isEnabled: true
    )

    init(
        name: String,
        scope: DraftBudgetScope,
        categoryId: String,
        accountId: String,
        amountText: String,
        isEnabled: Bool
    ) {
        self.name = name
        self.scope = scope
        self.categoryId = categoryId
        self.accountId = accountId
        self.amountText = amountText
        self.isEnabled = isEnabled
    }

    init(budget: DraftBudget) {
        self.name = budget.name
        self.scope = budget.scope
        self.categoryId = budget.scope == .category ? budget.targetId ?? "" : ""
        self.accountId = budget.scope == .account ? budget.targetId ?? "" : ""
        self.amountText = budget.amountText
        self.isEnabled = budget.isEnabled
    }

    var resolvedTargetId: String? {
        switch scope {
        case .overall:
            return nil
        case .category:
            return categoryId
        case .account:
            return accountId
        }
    }
}

private struct BudgetEditorSheet: View {
    let isEditing: Bool
    @Binding var draft: BudgetEditorDraft
    let accountItems: [BudgetSelectionItem]
    let categoryItems: [BudgetSelectionItem]
    let currencySymbol: String
    let onScopeChange: () -> Void
    let onCancel: () -> Void
    let onSave: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("budgets.name.placeholder", text: $draft.name)

                    Picker("budgets.scope", selection: $draft.scope) {
                        ForEach(DraftBudgetScope.allCases) { scope in
                            Text(scope.titleKey).tag(scope)
                        }
                    }
                    .onChange(of: draft.scope) { _, _ in
                        onScopeChange()
                    }

                    if draft.scope == .category {
                        NavigationLink {
                            BudgetSelectionPage(
                                titleKey: "budgets.target.category",
                                items: categoryItems,
                                selectedId: $draft.categoryId
                            )
                        } label: {
                            BudgetSelectionRow(
                                titleKey: "budgets.target.category",
                                item: selectedCategoryItem
                            )
                        }
                    } else if draft.scope == .account {
                        NavigationLink {
                            BudgetSelectionPage(
                                titleKey: "budgets.target.account",
                                items: accountItems,
                                selectedId: $draft.accountId
                            )
                        } label: {
                            BudgetSelectionRow(
                                titleKey: "budgets.target.account",
                                item: selectedAccountItem
                            )
                        }
                    }

                    RecordAmountInputRow(
                        placeholderKey: "budgets.amount.placeholder",
                        amountText: $draft.amountText,
                        currencySymbol: currencySymbol,
                        tint: .accentColor
                    )

                    Toggle("budgets.enabled", isOn: $draft.isEnabled)
                } header: {
                    Text("budgets.section.basic")
                } footer: {
                    Text("budgets.editor.footer")
                }
            }
            .navigationTitle(Text(isEditing ? "budgets.edit.title" : "budgets.add.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel", action: onCancel)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("common.save", action: onSave)
                        .disabled(!canSave)
                }
            }
        }
    }

    private var canSave: Bool {
        guard !draft.amountText.isEmpty else { return false }

        switch draft.scope {
        case .overall:
            return true
        case .category:
            return !draft.categoryId.isEmpty
        case .account:
            return !draft.accountId.isEmpty
        }
    }

    private var selectedCategoryItem: BudgetSelectionItem {
        categoryItems.first { $0.id == draft.categoryId } ?? .missing
    }

    private var selectedAccountItem: BudgetSelectionItem {
        accountItems.first { $0.id == draft.accountId } ?? .missing
    }
}

private struct BudgetSelectionItem: Identifiable, Equatable {
    var id: String
    var name: String
    var iconName: String
    var colorHex: String
    var subtitle: String = ""
    var depth: Int = 1

    static let missing = BudgetSelectionItem(
        id: "",
        name: NSLocalizedString("draft.item.missing", comment: ""),
        iconName: "circle-dollar-to-slot",
        colorHex: "#F6C343"
    )
}

private struct BudgetSelectionRow: View {
    let titleKey: LocalizedStringKey
    let item: BudgetSelectionItem

    var body: some View {
        HStack(spacing: 12) {
            Text(titleKey)
                .foregroundStyle(.primary)

            Spacer(minLength: 16)

            HStack(spacing: 8) {
                DraftVisualBadge(iconName: item.iconName, colorHex: item.colorHex, size: 24)

                Text(item.name)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: 220, alignment: .trailing)
        }
    }
}

private struct BudgetSelectionPage: View {
    let titleKey: LocalizedStringKey
    let items: [BudgetSelectionItem]
    @Binding var selectedId: String
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private var filteredItems: [BudgetSelectionItem] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return items }

        return items.filter { item in
            item.name.localizedCaseInsensitiveContains(query)
                || item.subtitle.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        List(filteredItems) { item in
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
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: Text("management.search.placeholder"))
    }
}
