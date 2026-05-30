import SwiftUI

struct RecordPage: View {
    @EnvironmentObject private var draftStore: DraftBookkeepingStore
    @Binding var selectedTab: AppTab

    @State private var selectedKind = DraftEntryKind.expense
    @State private var amountText = ""
    @State private var selectedCategoryId = ""
    @State private var selectedAccountId = ""
    @State private var selectedFromAccountId = ""
    @State private var selectedToAccountId = ""
    @State private var date = Date()
    @State private var note = ""
    @State private var errorKey: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("record.kind", selection: $selectedKind) {
                        ForEach(DraftEntryKind.allCases) { kind in
                            Text(kind.titleKey).tag(kind)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                amountSection

                if selectedKind == .transfer {
                    transferAccountSection
                } else {
                    categoryAndAccountSection
                }

                detailSection

                if let errorKey {
                    Section {
                        Text(LocalizedStringKey(errorKey))
                            .font(.subheadline)
                            .foregroundStyle(.red)
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
                    Button {
                        saveDraft()
                    } label: {
                        Label("record.action.saveDraft", systemImage: "checkmark.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                } footer: {
                    Text("record.footer.draftOnly")
                }
            }
            .navigationTitle(Text("tab.record"))
            .onAppear {
                normalizeSelections()
            }
            .onChange(of: selectedKind) { _, _ in
                errorKey = nil
                normalizeSelections()
            }
            .onChange(of: draftStore.accounts) { _, _ in
                normalizeSelections()
            }
            .onChange(of: draftStore.categories) { _, _ in
                normalizeSelections()
            }
        }
    }

    private var amountSection: some View {
        Section {
            TextField("record.amount.placeholder", text: $amountText)
                .keyboardType(.decimalPad)
        } header: {
            Text("record.section.amount")
        }
    }

    private var categoryAndAccountSection: some View {
        Section {
            Picker("record.category", selection: $selectedCategoryId) {
                Text("record.picker.unselected").tag("")
                ForEach(draftStore.categories(for: selectedKind)) { category in
                    HStack {
                        FontAwesomeIcon(name: category.iconName)
                        Text(category.name)
                    }
                    .tag(category.id)
                }
            }

            Picker("record.account", selection: $selectedAccountId) {
                Text("record.picker.unselected").tag("")
                ForEach(draftStore.accounts) { account in
                    HStack {
                        FontAwesomeIcon(name: account.iconName)
                        Text(account.name)
                    }
                    .tag(account.id)
                }
            }
        } header: {
            Text("record.section.bookkeeping")
        }
    }

    private var transferAccountSection: some View {
        Section {
            Picker("record.fromAccount", selection: $selectedFromAccountId) {
                Text("record.picker.unselected").tag("")
                ForEach(draftStore.accounts) { account in
                    HStack {
                        FontAwesomeIcon(name: account.iconName)
                        Text(account.name)
                    }
                    .tag(account.id)
                }
            }

            Picker("record.toAccount", selection: $selectedToAccountId) {
                Text("record.picker.unselected").tag("")
                ForEach(draftStore.accounts) { account in
                    HStack {
                        FontAwesomeIcon(name: account.iconName)
                        Text(account.name)
                    }
                    .tag(account.id)
                }
            }
        } header: {
            Text("record.section.transfer")
        }
    }

    private var detailSection: some View {
        Section {
            DatePicker("record.date", selection: $date, displayedComponents: [.date])

            TextField("record.note.placeholder", text: $note, axis: .vertical)
                .lineLimit(2...4)
        } header: {
            Text("record.section.detail")
        }
    }

    private func normalizeSelections() {
        let accounts = draftStore.accounts
        if !accounts.contains(where: { $0.id == selectedAccountId }) {
            selectedAccountId = accounts.first?.id ?? ""
        }
        if !accounts.contains(where: { $0.id == selectedFromAccountId }) {
            selectedFromAccountId = accounts.first?.id ?? ""
        }
        if !accounts.contains(where: { $0.id == selectedToAccountId }) {
            selectedToAccountId = accounts.dropFirst().first?.id ?? accounts.first?.id ?? ""
        }

        let categories = draftStore.categories(for: selectedKind)
        if selectedKind != .transfer, !categories.contains(where: { $0.id == selectedCategoryId }) {
            selectedCategoryId = categories.first?.id ?? ""
        }
    }

    private func saveDraft() {
        draftStore.clearMessage()

        guard isPositiveAmount(amountText) else {
            errorKey = "record.error.invalidAmount"
            return
        }

        switch selectedKind {
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

        let trimmedAmount = amountText.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let draft = DraftTransaction(
            id: UUID().uuidString,
            kind: selectedKind,
            amountText: trimmedAmount,
            categoryId: selectedKind == .transfer ? nil : selectedCategoryId,
            accountId: selectedKind == .transfer ? nil : selectedAccountId,
            fromAccountId: selectedKind == .transfer ? selectedFromAccountId : nil,
            toAccountId: selectedKind == .transfer ? selectedToAccountId : nil,
            date: date,
            note: trimmedNote,
            createdAt: Date()
        )

        draftStore.saveDraft(draft)
        errorKey = nil
        selectedTab = .transactions
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
    RecordPage(selectedTab: .constant(.record))
        .environmentObject(DraftBookkeepingStore())
}
