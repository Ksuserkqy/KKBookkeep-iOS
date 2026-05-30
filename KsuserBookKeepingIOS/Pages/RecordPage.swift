import SwiftUI

struct RecordPage: View {
    @EnvironmentObject private var draftStore: DraftBookkeepingStore
    @Binding var selectedTab: AppTab
    @StateObject private var locationProvider = CurrentLocationProvider()

    @State private var selectedKind = DraftEntryKind.expense
    @State private var amountText = ""
    @State private var transferInAmountText = ""
    @State private var selectedCategoryId = ""
    @State private var selectedAccountId = ""
    @State private var selectedFromAccountId = ""
    @State private var selectedToAccountId = ""
    @State private var date = Date()
    @State private var note = ""
    @State private var location: DraftLocation?
    @State private var isLocating = false
    @State private var locationMessageKey: String?
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

                if selectedKind == .transfer {
                    transferAmountSection
                } else {
                    amountSection
                }

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
                if selectedKind == .transfer, transferInAmountText.isEmpty {
                    transferInAmountText = amountText
                }
                normalizeSelections()
            }
            .onChange(of: amountText) { oldValue, newValue in
                guard selectedKind == .transfer else { return }
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

    private var amountSection: some View {
        Section {
            TextField("record.amount.placeholder", text: $amountText)
                .keyboardType(.decimalPad)
        } header: {
            Text("record.section.amount")
        }
    }

    private var transferAmountSection: some View {
        Section {
            TextField("record.transferOutAmount.placeholder", text: $amountText)
                .keyboardType(.decimalPad)

            TextField("record.transferInAmount.placeholder", text: $transferInAmountText)
                .keyboardType(.decimalPad)
        } header: {
            Text("record.section.transferAmount")
        } footer: {
            Text("record.transferAmount.footer")
        }
    }

    private var categoryAndAccountSection: some View {
        Section {
            NavigationLink {
                RecordVisualSelectionPage(
                    titleKey: "record.category",
                    items: categorySelectionItems(for: selectedKind),
                    selectedId: $selectedCategoryId
                )
            } label: {
                RecordVisualSelectionRow(
                    titleKey: "record.category",
                    item: categorySelectionItem(for: selectedCategoryId)
                )
            }

            NavigationLink {
                RecordVisualSelectionPage(
                    titleKey: "record.account",
                    items: accountSelectionItems,
                    selectedId: $selectedAccountId
                )
            } label: {
                RecordVisualSelectionRow(
                    titleKey: "record.account",
                    item: accountSelectionItem(for: selectedAccountId)
                )
            }
        } header: {
            Text("record.section.bookkeeping")
        }
    }

    private var transferAccountSection: some View {
        Section {
            NavigationLink {
                RecordVisualSelectionPage(
                    titleKey: "record.fromAccount",
                    items: accountSelectionItems,
                    selectedId: $selectedFromAccountId
                )
            } label: {
                RecordVisualSelectionRow(
                    titleKey: "record.fromAccount",
                    item: accountSelectionItem(for: selectedFromAccountId)
                )
            }

            NavigationLink {
                RecordVisualSelectionPage(
                    titleKey: "record.toAccount",
                    items: accountSelectionItems,
                    selectedId: $selectedToAccountId
                )
            } label: {
                RecordVisualSelectionRow(
                    titleKey: "record.toAccount",
                    item: accountSelectionItem(for: selectedToAccountId)
                )
            }
        } header: {
            Text("record.section.transfer")
        }
    }

    private var detailSection: some View {
        Section {
            DatePicker("record.dateTime", selection: $date, displayedComponents: [.date, .hourAndMinute])

            locationRow

            TextField("record.note.placeholder", text: $note, axis: .vertical)
                .lineLimit(2...4)
        } header: {
            Text("record.section.detail")
        }
    }

    @ViewBuilder
    private var locationRow: some View {
        if let location {
            VStack(alignment: .leading, spacing: 8) {
                Label {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(location.displayName)
                            .foregroundStyle(.primary)

                        Text(location.coordinateText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "location.fill")
                        .foregroundStyle(.tint)
                }

                Button(role: .destructive) {
                    self.location = nil
                    locationMessageKey = nil
                } label: {
                    Label("record.location.remove", systemImage: "xmark.circle")
                }
                .font(.subheadline)
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

        let categories = draftStore.categories(for: selectedKind)
        if selectedKind != .transfer, !categories.contains(where: { $0.id == selectedCategoryId }) {
            selectedCategoryId = defaultCategoryId(in: categories)
        }
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

    private var accountSelectionItems: [RecordVisualSelectionItem] {
        draftStore.accounts.map { account in
            RecordVisualSelectionItem(
                id: account.id,
                name: account.name,
                iconName: account.iconName,
                colorHex: account.colorHex
            )
        }
    }

    private func categorySelectionItems(for kind: DraftEntryKind) -> [RecordVisualSelectionItem] {
        draftStore.categoryHierarchyItems(for: kind).map { item in
            let category = item.category

            return RecordVisualSelectionItem(
                id: category.id,
                name: category.name,
                iconName: category.iconName,
                colorHex: category.colorHex,
                depth: item.depth
            )
        }
    }

    private func accountSelectionItem(for id: String) -> RecordVisualSelectionItem {
        accountSelectionItems.first { $0.id == id } ?? Self.unselectedSelectionItem
    }

    private func categorySelectionItem(for id: String) -> RecordVisualSelectionItem {
        guard let category = draftStore.categories.first(where: { $0.id == id }) else {
            return Self.unselectedSelectionItem
        }

        return RecordVisualSelectionItem(
            id: category.id,
            name: draftStore.categoryDisplayName(for: category.id),
            iconName: category.iconName,
            colorHex: category.colorHex
        )
    }

    private static var unselectedSelectionItem: RecordVisualSelectionItem {
        RecordVisualSelectionItem(
            id: "",
            name: NSLocalizedString("record.picker.unselected", comment: ""),
            iconName: "circle-question",
            colorHex: "#64748B",
            depth: 1
        )
    }

    private func saveDraft() {
        draftStore.clearMessage()

        guard isPositiveAmount(amountText) else {
            errorKey = "record.error.invalidAmount"
            return
        }

        if selectedKind == .transfer {
            guard isPositiveAmount(transferInAmountText) else {
                errorKey = "record.error.invalidTransferInAmount"
                return
            }
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
        let trimmedTransferInAmount = transferInAmountText.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let draft = DraftTransaction(
            id: UUID().uuidString,
            kind: selectedKind,
            amountText: trimmedAmount,
            transferInAmountText: selectedKind == .transfer ? trimmedTransferInAmount : nil,
            categoryId: selectedKind == .transfer ? nil : selectedCategoryId,
            accountId: selectedKind == .transfer ? nil : selectedAccountId,
            fromAccountId: selectedKind == .transfer ? selectedFromAccountId : nil,
            toAccountId: selectedKind == .transfer ? selectedToAccountId : nil,
            date: date,
            note: trimmedNote,
            location: location,
            createdAt: Date()
        )

        draftStore.saveDraft(draft)
        errorKey = nil
        selectedTab = .transactions
    }

    private func captureLocation() {
        guard !isLocating else { return }

        isLocating = true
        locationMessageKey = "record.location.locating"

        Task {
            do {
                location = try await locationProvider.captureLocation()
                locationMessageKey = nil
            } catch CurrentLocationProvider.ProviderError.denied {
                locationMessageKey = "record.location.error.denied"
            } catch {
                locationMessageKey = "record.location.error.unavailable"
            }

            isLocating = false
        }
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

private struct RecordVisualSelectionItem: Identifiable, Equatable {
    let id: String
    let name: String
    let iconName: String
    let colorHex: String
    var depth: Int = 1
}

private struct RecordVisualSelectionRow: View {
    let titleKey: LocalizedStringKey
    let item: RecordVisualSelectionItem

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
        }
    }
}

private struct RecordVisualSelectionPage: View {
    let titleKey: LocalizedStringKey
    let items: [RecordVisualSelectionItem]
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

                    Text(item.name)
                        .foregroundStyle(.primary)

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

#Preview {
    RecordPage(selectedTab: .constant(.record))
        .environmentObject(DraftBookkeepingStore())
}
