import MapKit
import SwiftUI

struct TransactionsPage: View {
    @EnvironmentObject private var draftStore: DraftBookkeepingStore
    @EnvironmentObject private var profileStore: ProfileStore
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
                            TransactionSummaryCard(
                                transaction: transaction,
                                localizedTitle: localizedTitle(for: transaction.kind),
                                accountItem: accountItem(for: transaction),
                                categoryItem: categoryItem(for: transaction),
                                dateText: Self.dateFormatter.string(from: transaction.date),
                                onEdit: {
                                    editingTransaction = transaction
                                }
                            )
                            .padding(.vertical, 6)
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
                    .environmentObject(profileStore)
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
                name: NSLocalizedString("draft.item.missing", comment: ""),
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
        return String(format: NSLocalizedString("draft.item.archivedFormat", comment: ""), name)
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
            .contentShape(Rectangle())
            .onTapGesture(perform: onEdit)

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
            .contentShape(Rectangle())
            .onTapGesture(perform: onEdit)

            if let location = transaction.location {
                TransactionLocationButton(location: location, font: .caption)
            }

            if !transaction.note.isEmpty {
                Text(transaction.note)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture(perform: onEdit)
            }
        }
    }
}

private struct TransactionLocationButton: View {
    let location: DraftLocation
    var font: Font = .body

    var body: some View {
        Button {
            location.openInMaps()
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
                    format: NSLocalizedString("transactions.location.openInMaps.accessibility", comment: ""),
                    location.displayName
                )
            )
        )
    }
}

private extension DraftLocation {
    func openInMaps() {
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
            name: NSLocalizedString("record.picker.unselected", comment: ""),
            iconName: "circle-question",
            colorHex: "#64748B",
            subtitle: "",
            depth: 1
        )
    }

    private func archivedAwareName(_ name: String, isArchived: Bool) -> String {
        guard isArchived else { return name }
        return String(format: NSLocalizedString("draft.item.archivedFormat", comment: ""), name)
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
}
