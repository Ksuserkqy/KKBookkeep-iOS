import SwiftUI

struct TransactionsPage: View {
    @EnvironmentObject private var draftStore: DraftBookkeepingStore
    @State private var editingTransaction: DraftTransaction?
    @State private var deletingTransaction: DraftTransaction?

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
                        ForEach(draftStore.transactions) { transaction in
                            Button {
                                editingTransaction = transaction
                            } label: {
                                TransactionSummaryCard(
                                    transaction: transaction,
                                    localizedTitle: localizedTitle(for: transaction.kind),
                                    accountItem: accountItem(for: transaction),
                                    categoryItem: categoryItem(for: transaction),
                                    dateText: Self.dateFormatter.string(from: transaction.date)
                                )
                                .padding(.vertical, 6)
                            }
                            .buttonStyle(.plain)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    deletingTransaction = transaction
                                } label: {
                                    Label("management.action.delete", systemImage: "trash")
                                }
                            }
                            .contextMenu {
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
                    } footer: {
                        Text("transactions.footer.localOnly")
                    }
                }
            }
            .navigationTitle(Text("tab.transactions"))
            .sheet(item: $editingTransaction) { transaction in
                TransactionEditorPage(transaction: transaction)
                    .environmentObject(draftStore)
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

    private func localizedTitle(for kind: DraftEntryKind) -> String {
        NSLocalizedString(kind.localizationKey, comment: "")
    }

    private func accountItem(for id: String?) -> DraftVisualSummaryItem {
        guard
            let id,
            let account = draftStore.accounts.first(where: { $0.id == id })
        else {
            return DraftVisualSummaryItem(
                name: NSLocalizedString("draft.item.missing", comment: ""),
                iconName: "circle-question",
                colorHex: "#64748B"
            )
        }

        return DraftVisualSummaryItem(name: account.name, iconName: account.iconName, colorHex: account.colorHex)
    }

    private func categoryItem(for id: String?) -> DraftVisualSummaryItem {
        guard
            let id,
            let category = draftStore.categories.first(where: { $0.id == id })
        else {
            return DraftVisualSummaryItem(
                name: NSLocalizedString("draft.item.missing", comment: ""),
                iconName: "circle-question",
                colorHex: "#64748B"
            )
        }

        return DraftVisualSummaryItem(
            name: draftStore.categoryDisplayName(for: category.id),
            iconName: category.iconName,
            colorHex: category.colorHex
        )
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
                    format: NSLocalizedString("dashboard.transferAccountFormat", comment: ""),
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
                name: NSLocalizedString("record.kind.transfer", comment: ""),
                iconName: "right-left",
                colorHex: "#3B82F6"
            )
        }
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}

private struct TransactionSummaryCard: View {
    let transaction: DraftTransaction
    let localizedTitle: String
    let accountItem: DraftVisualSummaryItem
    let categoryItem: DraftVisualSummaryItem
    let dateText: String

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
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                DraftVisualBadge(iconName: categoryItem.iconName, colorHex: categoryItem.colorHex, size: 34)

                VStack(alignment: .leading, spacing: 3) {
                    Text(categoryItem.name)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)

                    Text(localizedTitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 12)

                Text(amountText)
                    .font(.headline)
                    .foregroundStyle(amountColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }

            HStack(spacing: 8) {
                DraftVisualBadge(iconName: accountItem.iconName, colorHex: accountItem.colorHex, size: 22)

                Text(accountItem.name)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer(minLength: 8)

                Text(dateText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let location = transaction.location {
                Label(location.displayName, systemImage: "location.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            if !transaction.note.isEmpty {
                Text(transaction.note)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
    }
}

private struct DraftVisualSummaryItem {
    let name: String
    let iconName: String
    let colorHex: String
}

private struct TransactionEditorPage: View {
    @EnvironmentObject private var draftStore: DraftBookkeepingStore
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
                        TextField("record.transferOutAmount.placeholder", text: $amountText)
                            .keyboardType(.decimalPad)

                        TextField("record.transferInAmount.placeholder", text: $transferInAmountText)
                            .keyboardType(.decimalPad)
                    } header: {
                        Text("record.section.transferAmount")
                    }

                    Section {
                        Picker("record.fromAccount", selection: $selectedFromAccountId) {
                            ForEach(draftStore.accounts) { account in
                                Text(account.name).tag(account.id)
                            }
                        }

                        Picker("record.toAccount", selection: $selectedToAccountId) {
                            ForEach(draftStore.accounts) { account in
                                Text(account.name).tag(account.id)
                            }
                        }
                    } header: {
                        Text("record.section.transfer")
                    }
                } else {
                    Section {
                        TextField("record.amount.placeholder", text: $amountText)
                            .keyboardType(.decimalPad)
                    } header: {
                        Text("record.section.amount")
                    }

                    Section {
                        Picker("record.category", selection: $selectedCategoryId) {
                            ForEach(draftStore.categoryHierarchyItems(for: transaction.kind)) { item in
                                Text(categoryTitle(for: item)).tag(item.category.id)
                            }
                        }

                        Picker("record.account", selection: $selectedAccountId) {
                            ForEach(draftStore.accounts) { account in
                                Text(account.name).tag(account.id)
                            }
                        }
                    } header: {
                        Text("record.section.bookkeeping")
                    }
                }

                Section {
                    DatePicker("record.dateTime", selection: $date, displayedComponents: [.date, .hourAndMinute])

                    if let location = transaction.location {
                        Label(location.displayName, systemImage: "location.fill")
                            .foregroundStyle(.secondary)
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

    private func save() {
        draftStore.clearMessage()

        guard isPositiveAmount(amountText) else {
            errorKey = "record.error.invalidAmount"
            return
        }

        if transaction.kind == .transfer {
            guard isPositiveAmount(transferInAmountText) else {
                errorKey = "record.error.invalidTransferInAmount"
                return
            }
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
            amountText: amountText.trimmingCharacters(in: .whitespacesAndNewlines),
            transferInAmountText: transaction.kind == .transfer ? transferInAmountText.trimmingCharacters(in: .whitespacesAndNewlines) : nil,
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
        let accounts = draftStore.accounts
        if !accounts.contains(where: { $0.id == selectedAccountId }) {
            selectedAccountId = defaultAccountId(in: accounts)
        }
        if !accounts.contains(where: { $0.id == selectedFromAccountId }) {
            selectedFromAccountId = defaultAccountId(in: accounts)
        }
        if !accounts.contains(where: { $0.id == selectedToAccountId }) {
            selectedToAccountId = defaultTransferDestinationAccountId(in: accounts)
        }

        let categories = draftStore.categories(for: transaction.kind)
        if transaction.kind != .transfer, !categories.contains(where: { $0.id == selectedCategoryId }) {
            selectedCategoryId = defaultCategoryId(in: categories)
        }
    }

    private func categoryTitle(for item: DraftCategoryHierarchyItem) -> String {
        String(repeating: "  ", count: max(item.depth - 1, 0)) + draftStore.categoryDisplayName(for: item.category.id)
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
        let normalizedText = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")

        guard
            let decimal = Decimal(string: normalizedText),
            decimal > 0
        else {
            return false
        }

        return true
    }
}

#Preview {
    TransactionsPage()
        .environmentObject(DraftBookkeepingStore())
}
