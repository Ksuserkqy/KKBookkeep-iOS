import SwiftUI

struct TransactionTemplateManagementPage: View {
    @EnvironmentObject private var draftStore: DraftBookkeepingStore
    @EnvironmentObject private var profileStore: ProfileStore
    @EnvironmentObject private var syncSettingsStore: SyncSettingsStore
    @State private var selectedKind = DraftEntryKind.expense
    @State private var editingTemplate: DraftTransactionTemplate?
    @State private var deletingTemplate: DraftTransactionTemplate?
    @State private var draft = TransactionTemplateEditorDraft.empty
    @State private var isEditorPresented = false
    @State private var isSyncingTemplates = false
    @State private var hasPendingTemplateSync = false

    private var filteredTemplates: [DraftTransactionTemplate] {
        draftStore.transactionTemplates.filter { $0.kind == selectedKind }
    }

    var body: some View {
        Form {
            Section {
                Picker("templates.kind", selection: $selectedKind) {
                    Label("record.kind.expense", systemImage: "minus.circle.fill")
                        .labelStyle(.titleAndIcon)
                        .tag(DraftEntryKind.expense)
                    Label("record.kind.income", systemImage: "plus.circle.fill")
                        .labelStyle(.titleAndIcon)
                        .tag(DraftEntryKind.income)
                }
                .pickerStyle(.segmented)
            }

            Section {
                Button {
                    beginAdding()
                } label: {
                    Label("templates.add", systemImage: "plus.circle.fill")
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
                if filteredTemplates.isEmpty {
                    ContentUnavailableView(
                        "templates.empty.title",
                        systemImage: "doc.text.magnifyingglass",
                        description: Text("templates.empty.subtitle")
                    )
                    .padding(.vertical, 18)
                } else {
                    ForEach(filteredTemplates) { template in
                        TransactionTemplateRow(
                            template: template,
                            accountName: draftStore.accountName(for: template.accountId),
                            categoryName: draftStore.categoryDisplayName(for: template.categoryId),
                            categoryItem: categoryItem(for: template),
                            onEdit: {
                                beginEditing(template)
                            }
                        )
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                deletingTemplate = template
                            } label: {
                                Label("management.action.delete", systemImage: "trash")
                            }
                            .tint(.red)

                            Button {
                                beginEditing(template)
                            } label: {
                                Label("management.action.edit", systemImage: "pencil")
                            }
                            .tint(.accentColor)
                        }
                    }
                }
            } header: {
                Text("templates.section")
            } footer: {
                Text("templates.footer")
            }
        }
        .navigationTitle(Text("templates.title"))
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                AppBackButton()
            }
        }
        .sheet(isPresented: $isEditorPresented) {
            TransactionTemplateEditorSheet(
                isEditing: editingTemplate != nil,
                draft: $draft,
                accountItems: accountSelectionItems,
                categoryItems: categorySelectionItems(for: draft.kind),
                currencySymbol: profileStore.profile.currency.symbol,
                onKindChange: normalizeDraftSelections,
                onCancel: {
                    isEditorPresented = false
                },
                onSave: {
                    saveTemplate()
                }
            )
        }
        .confirmationDialog(
            Text("templates.delete.confirm.title"),
            isPresented: Binding(
                get: { deletingTemplate != nil },
                set: { isPresented in
                    if !isPresented {
                        deletingTemplate = nil
                    }
                }
            ),
            titleVisibility: .visible
        ) {
            Button("management.action.delete", role: .destructive) {
                deletePendingTemplate()
            }

            Button("common.cancel", role: .cancel) {
                deletingTemplate = nil
            }
        } message: {
            Text("templates.delete.confirm.message")
        }
    }

    private func beginAdding() {
        editingTemplate = nil
        draft = .empty
        draft.kind = selectedKind
        normalizeDraftSelections()
        isEditorPresented = true
    }

    private func beginEditing(_ template: DraftTransactionTemplate) {
        editingTemplate = template
        draft = TransactionTemplateEditorDraft(template: template)
        normalizeDraftSelections()
        isEditorPresented = true
    }

    private func saveTemplate() {
        if let editingTemplate {
            if draftStore.updateTransactionTemplate(
                id: editingTemplate.id,
                name: draft.name,
                kind: draft.kind,
                amountText: draft.amountText,
                categoryId: draft.categoryId,
                accountId: draft.accountId,
                note: draft.note
            ) {
                selectedKind = draft.kind
                isEditorPresented = false
                syncTemplatesAfterMutation()
            }
        } else if draftStore.addTransactionTemplate(
            name: draft.name,
            kind: draft.kind,
            amountText: draft.amountText,
            categoryId: draft.categoryId,
            accountId: draft.accountId,
            note: draft.note
        ) {
            selectedKind = draft.kind
            isEditorPresented = false
            syncTemplatesAfterMutation()
        }
    }

    private func syncTemplatesAfterMutation() {
        let configuration = syncSettingsStore.configuration
        guard configuration.backupEnabled else { return }

        guard !isSyncingTemplates else {
            hasPendingTemplateSync = true
            return
        }

        isSyncingTemplates = true
        let secrets = syncSettingsStore.secrets(for: configuration)

        Task {
            let didBackup = await draftStore.backupTemplatesAfterLocalChange(
                configuration: configuration,
                secrets: secrets
            )
            if didBackup {
                try? syncSettingsStore.markBackupCompleted()
            }
            isSyncingTemplates = false

            if hasPendingTemplateSync {
                hasPendingTemplateSync = false
                syncTemplatesAfterMutation()
            }
        }
    }

    private func deletePendingTemplate() {
        guard let deletingTemplate else { return }

        let didDelete = draftStore.deleteTransactionTemplate(id: deletingTemplate.id)
        self.deletingTemplate = nil
        if didDelete {
            syncTemplatesAfterMutation()
        }
    }

    private func normalizeDraftSelections() {
        if !accountSelectionItems.contains(where: { $0.id == draft.accountId }) {
            draft.accountId = defaultAccountId
        }

        let categoryItems = categorySelectionItems(for: draft.kind)
        if !categoryItems.contains(where: { $0.id == draft.categoryId }) {
            draft.categoryId = categoryItems.first?.id ?? ""
        }
    }

    private var defaultAccountId: String {
        draftStore.accounts.first { !$0.isArchived && $0.isDefault }?.id
            ?? draftStore.accounts.first { !$0.isArchived }?.id
            ?? ""
    }

    private var accountSelectionItems: [TransactionTemplateSelectionItem] {
        draftStore.accounts.filter { !$0.isArchived }.map { account in
            TransactionTemplateSelectionItem(
                id: account.id,
                name: account.name,
                iconName: account.iconName,
                colorHex: account.colorHex,
                subtitle: draftStore.accountBalanceSummary(for: account.id)
            )
        }
    }

    private func categorySelectionItems(for kind: DraftEntryKind) -> [TransactionTemplateSelectionItem] {
        draftStore.categoryHierarchyItems(for: kind).map { item in
            TransactionTemplateSelectionItem(
                id: item.category.id,
                name: item.category.name,
                iconName: item.category.iconName,
                colorHex: item.category.colorHex,
                subtitle: draftStore.categoryTodaySummary(for: item.category.id),
                depth: item.depth
            )
        }
    }

    private func categoryItem(for template: DraftTransactionTemplate) -> TransactionTemplateSelectionItem {
        guard let category = draftStore.categories.first(where: { $0.id == template.categoryId }) else {
            return .missing
        }

        return TransactionTemplateSelectionItem(
            id: category.id,
            name: draftStore.categoryDisplayName(for: category.id),
            iconName: category.iconName,
            colorHex: category.colorHex
        )
    }
}

private struct TransactionTemplateRow: View {
    let template: DraftTransactionTemplate
    let accountName: String
    let categoryName: String
    let categoryItem: TransactionTemplateSelectionItem
    let onEdit: () -> Void

    private var amountText: String {
        switch template.kind {
        case .expense:
            return "-\(DraftAmountFormatter.currencyText(from: template.amountText))"
        case .income:
            return "+\(DraftAmountFormatter.currencyText(from: template.amountText))"
        case .transfer:
            return DraftAmountFormatter.currencyText(from: template.amountText)
        }
    }

    private var amountColor: Color {
        template.kind == .expense ? .red : .green
    }

    var body: some View {
        HStack(spacing: 12) {
            DraftVisualBadge(iconName: categoryItem.iconName, colorHex: categoryItem.colorHex)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(template.name)
                        .font(.headline.weight(.semibold))
                        .lineLimit(1)

                    Text(template.kind.titleKey)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                Text(categoryName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                HStack(spacing: 5) {
                    Text(accountName)

                    if !template.note.isEmpty {
                        Text("·")
                        Text(template.note)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }

            Spacer(minLength: 12)

            VStack(alignment: .trailing, spacing: 8) {
                Text(amountText)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(amountColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                HStack(spacing: 12) {
                    Button(action: onEdit) {
                        Image(systemName: "pencil")
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel(Text("management.action.edit"))
                }
                .font(.body.weight(.semibold))
            }
        }
        .padding(.vertical, 4)
    }
}

private struct TransactionTemplateEditorDraft {
    var name: String
    var kind: DraftEntryKind
    var amountText: String
    var categoryId: String
    var accountId: String
    var note: String

    static let empty = TransactionTemplateEditorDraft(
        name: "",
        kind: .expense,
        amountText: "",
        categoryId: "",
        accountId: "",
        note: ""
    )

    init(
        name: String,
        kind: DraftEntryKind,
        amountText: String,
        categoryId: String,
        accountId: String,
        note: String
    ) {
        self.name = name
        self.kind = kind
        self.amountText = amountText
        self.categoryId = categoryId
        self.accountId = accountId
        self.note = note
    }

    init(template: DraftTransactionTemplate) {
        self.name = template.name
        self.kind = template.kind
        self.amountText = template.amountText
        self.categoryId = template.categoryId
        self.accountId = template.accountId
        self.note = template.note
    }
}

private extension TransactionTemplateEditorDraft {
    var isSaveEnabled: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && normalizedPositiveAmountText(amountText) != nil
            && !categoryId.isEmpty
            && !accountId.isEmpty
    }

    private func normalizedPositiveAmountText(_ text: String) -> String? {
        guard
            let amountText = DraftAmountFormatter.normalizedAmountText(text, allowNegative: false),
            let decimal = Decimal(string: amountText, locale: Locale(identifier: "en_US_POSIX")),
            decimal > 0
        else {
            return nil
        }

        return amountText
    }
}

private struct TransactionTemplateEditorSheet: View {
    @Binding var draft: TransactionTemplateEditorDraft
    let isEditing: Bool
    let accountItems: [TransactionTemplateSelectionItem]
    let categoryItems: [TransactionTemplateSelectionItem]
    let currencySymbol: String
    let onKindChange: () -> Void
    let onCancel: () -> Void
    let onSave: () -> Void

    init(
        isEditing: Bool,
        draft: Binding<TransactionTemplateEditorDraft>,
        accountItems: [TransactionTemplateSelectionItem],
        categoryItems: [TransactionTemplateSelectionItem],
        currencySymbol: String,
        onKindChange: @escaping () -> Void,
        onCancel: @escaping () -> Void,
        onSave: @escaping () -> Void
    ) {
        self.isEditing = isEditing
        self._draft = draft
        self.accountItems = accountItems
        self.categoryItems = categoryItems
        self.currencySymbol = currencySymbol
        self.onKindChange = onKindChange
        self.onCancel = onCancel
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("templates.kind", selection: $draft.kind) {
                        Label("record.kind.expense", systemImage: "minus.circle.fill")
                            .labelStyle(.titleAndIcon)
                            .tag(DraftEntryKind.expense)
                        Label("record.kind.income", systemImage: "plus.circle.fill")
                            .labelStyle(.titleAndIcon)
                            .tag(DraftEntryKind.income)
                    }
                    .pickerStyle(.segmented)

                    TextField("templates.name.placeholder", text: $draft.name)

                    RecordAmountInputRow(
                        placeholderKey: "record.amount.placeholder",
                        amountText: $draft.amountText,
                        currencySymbol: currencySymbol,
                        tint: draft.kind == .expense ? .red : .green
                    )
                } header: {
                    Text("templates.section.basic")
                }

                Section {
                    NavigationLink {
                        TransactionTemplateSelectionPage(
                            titleKey: "record.category",
                            items: categoryItems,
                            selectedId: $draft.categoryId
                        )
                    } label: {
                        TransactionTemplateSelectionRow(
                            titleKey: "record.category",
                            item: selectedCategoryItem
                        )
                    }

                    NavigationLink {
                        TransactionTemplateSelectionPage(
                            titleKey: "record.account",
                            items: accountItems,
                            selectedId: $draft.accountId
                        )
                    } label: {
                        TransactionTemplateSelectionRow(
                            titleKey: "record.account",
                            item: selectedAccountItem
                        )
                    }
                } header: {
                    Text("record.section.bookkeeping")
                }

                Section {
                    TextField("record.note.placeholder", text: $draft.note, axis: .vertical)
                        .lineLimit(2...4)
                } header: {
                    Text("record.section.detail")
                }
            }
            .navigationTitle(Text(LocalizedStringKey(isEditing ? "templates.edit.title" : "templates.add.title")))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: onCancel) {
                        Label("common.cancel", systemImage: "xmark")
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(action: onSave) {
                        Label("common.save", systemImage: "checkmark")
                    }
                    .disabled(!draft.isSaveEnabled)
                }
            }
            .onChange(of: draft.kind) { _, _ in
                onKindChange()
            }
        }
    }

    private var selectedAccountItem: TransactionTemplateSelectionItem {
        accountItems.first { $0.id == draft.accountId } ?? .missing
    }

    private var selectedCategoryItem: TransactionTemplateSelectionItem {
        categoryItems.first { $0.id == draft.categoryId } ?? .missing
    }
}

private struct TransactionTemplateSelectionItem: Identifiable, Equatable {
    let id: String
    let name: String
    let iconName: String
    let colorHex: String
    var subtitle: String = ""
    var depth: Int = 1

    static let missing = TransactionTemplateSelectionItem(
        id: "",
        name: NSLocalizedString("record.picker.unselected", comment: ""),
        iconName: "circle-question",
        colorHex: "#64748B"
    )
}

private struct TransactionTemplateSelectionRow: View {
    let titleKey: LocalizedStringKey
    let item: TransactionTemplateSelectionItem

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

private struct TransactionTemplateSelectionPage: View {
    let titleKey: LocalizedStringKey
    let items: [TransactionTemplateSelectionItem]
    @Binding var selectedId: String
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private var filteredItems: [TransactionTemplateSelectionItem] {
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
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: Text("record.selection.search.placeholder"))
    }
}

#Preview {
    NavigationStack {
        TransactionTemplateManagementPage()
            .environmentObject(DraftBookkeepingStore())
            .environmentObject(ProfileStore())
            .environmentObject(SyncSettingsStore())
    }
}
