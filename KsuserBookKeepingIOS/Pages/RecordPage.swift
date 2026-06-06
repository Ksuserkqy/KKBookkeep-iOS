import SwiftUI

struct RecordPage: View {
    @EnvironmentObject private var draftStore: DraftBookkeepingStore
    @EnvironmentObject private var profileStore: ProfileStore
    @Binding var selectedTab: AppTab
    @Binding var requestedKind: DraftEntryKind?
    @StateObject private var locationProvider = CurrentLocationProvider()

    @State private var selectedKind = DraftEntryKind.expense
    @State private var entryMode = RecordEntryMode.single
    @State private var amountText = ""
    @State private var transferInAmountText = ""
    @State private var selectedCategoryId = ""
    @State private var selectedAccountId = ""
    @State private var selectedFromAccountId = ""
    @State private var selectedToAccountId = ""
    @State private var date = Date()
    @State private var note = ""
    @State private var location: DraftLocation?
    @State private var batchDateComponents: Set<DateComponents> = []
    @State private var isLocating = false
    @State private var locationCaptureToken = 0
    @State private var locationMessageKey: String?
    @State private var errorKey: String?

    private var availableTemplates: [DraftTransactionTemplate] {
        return draftStore.transactionTemplates.filter { template in
            template.kind == selectedKind &&
                draftStore.accounts.contains { $0.id == template.accountId && !$0.isArchived } &&
                draftStore.categories.contains { $0.id == template.categoryId && $0.kind == selectedKind && !$0.isArchived }
        }
    }

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

                templateSection

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

                if isBatchEntry {
                    batchDateSection
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

            }
            .navigationTitle(Text("tab.record"))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if selectedKind != .transfer {
                        Button {
                            toggleEntryMode()
                        } label: {
                            Label {
                                Text(LocalizedStringKey(isBatchEntry ? "record.entryMode.single" : "record.entryMode.batch"))
                            } icon: {
                                Image(systemName: isBatchEntry ? "doc.text" : "calendar.badge.plus")
                            }
                        }
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        saveTransaction()
                    } label: {
                        Text(LocalizedStringKey(isBatchEntry ? "record.batch.action.saveTransactions" : "record.action.saveTransaction"))
                            .font(.headline)
                    }
                }
            }
            .onAppear {
                applyRequestedKindIfNeeded()
                normalizeSelections()
            }
            .onChange(of: requestedKind) { _, _ in
                applyRequestedKindIfNeeded()
                normalizeSelections()
            }
            .onChange(of: selectedKind) { _, _ in
                errorKey = nil
                if selectedKind == .transfer {
                    entryMode = .single
                }
                if selectedKind == .transfer, transferInAmountText.isEmpty {
                    transferInAmountText = amountText
                }
                normalizeSelections()
            }
            .onChange(of: entryMode) { _, _ in
                errorKey = nil
                ensureBatchDateSelectionIfNeeded()
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

    private var isBatchEntry: Bool {
        selectedKind != .transfer && entryMode == .batch
    }

    private var amountSection: some View {
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
    }

    private var transferAmountSection: some View {
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
        } footer: {
            Text("record.transferAmount.footer")
        }
    }

    private var amountTint: Color {
        switch selectedKind {
        case .expense:
            return .red
        case .income:
            return .green
        case .transfer:
            return .primary
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

    @ViewBuilder
    private var templateSection: some View {
        if !availableTemplates.isEmpty {
            Section {
                NavigationLink {
                    RecordTemplateSelectionPage(
                        templates: availableTemplates,
                        categoryItem: { categorySelectionItem(for: $0) },
                        categoryName: { draftStore.categoryDisplayName(for: $0) },
                        accountName: { draftStore.accountName(for: $0) },
                        onSelect: { applyTemplate($0) }
                    )
                } label: {
                    HStack(spacing: 12) {
                        Label("record.templates.choose", systemImage: "doc.text.magnifyingglass")
                            .foregroundStyle(.primary)

                        Spacer()

                        Text(String(format: NSLocalizedString("record.templates.countFormat", comment: ""), availableTemplates.count))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("record.templates.section")
            } footer: {
                Text("record.templates.footer")
            }
        }
    }

    private var batchDateSection: some View {
        Section {
            MultiDatePicker("record.batch.dates", selection: $batchDateComponents)
        } header: {
            Text("record.batch.section.dates")
        } footer: {
            Text(
                String(
                    format: NSLocalizedString("record.batch.selectedCountFormat", comment: ""),
                    batchDateComponents.count
                )
            )
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
            if isBatchEntry {
                DatePicker("record.batch.time", selection: $date, displayedComponents: [.hourAndMinute])
            } else {
                DatePicker("record.dateTime", selection: $date, displayedComponents: [.date, .hourAndMinute])
            }

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
        let accounts = draftStore.accounts.filter { !$0.isArchived }
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

    private func applyRequestedKindIfNeeded() {
        guard let requestedKind else { return }

        selectedKind = requestedKind
        if requestedKind == .transfer {
            entryMode = .single
        }
        self.requestedKind = nil
    }

    private func toggleEntryMode() {
        guard selectedKind != .transfer else {
            entryMode = .single
            return
        }

        entryMode = isBatchEntry ? .single : .batch
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

    private func applyTemplate(_ template: DraftTransactionTemplate) {
        selectedKind = template.kind
        amountText = template.amountText
        transferInAmountText = ""
        selectedCategoryId = template.categoryId
        selectedAccountId = template.accountId
        note = template.note
        date = Date()
        location = nil
        locationMessageKey = nil
        errorKey = nil
        normalizeSelections()
    }

    private var accountSelectionItems: [RecordVisualSelectionItem] {
        draftStore.accounts.filter { !$0.isArchived }.map { account in
            RecordVisualSelectionItem(
                id: account.id,
                name: account.name,
                iconName: account.iconName,
                colorHex: account.colorHex,
                subtitle: draftStore.accountBalanceSummary(for: account.id)
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
                subtitle: draftStore.categoryTodaySummary(for: category.id),
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
            colorHex: category.colorHex,
            subtitle: draftStore.categoryTodaySummary(for: category.id)
        )
    }

    private static var unselectedSelectionItem: RecordVisualSelectionItem {
        RecordVisualSelectionItem(
            id: "",
            name: NSLocalizedString("record.picker.unselected", comment: ""),
            iconName: "circle-question",
            colorHex: "#64748B",
            subtitle: "",
            depth: 1
        )
    }

    private func saveTransaction() {
        if isBatchEntry {
            saveBatchTransactions()
            return
        }

        draftStore.clearMessage()

        guard let normalizedAmount = normalizedPositiveAmountText(amountText) else {
            errorKey = "record.error.invalidAmount"
            return
        }

        let normalizedTransferInAmount: String?
        if selectedKind == .transfer {
            guard let amount = normalizedPositiveAmountText(transferInAmountText) else {
                errorKey = "record.error.invalidTransferInAmount"
                return
            }
            normalizedTransferInAmount = amount
        } else {
            normalizedTransferInAmount = nil
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

        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let transaction = DraftTransaction(
            id: UUID().uuidString,
            kind: selectedKind,
            amountText: normalizedAmount,
            transferInAmountText: normalizedTransferInAmount,
            categoryId: selectedKind == .transfer ? nil : selectedCategoryId,
            accountId: selectedKind == .transfer ? nil : selectedAccountId,
            fromAccountId: selectedKind == .transfer ? selectedFromAccountId : nil,
            toAccountId: selectedKind == .transfer ? selectedToAccountId : nil,
            date: date,
            note: trimmedNote,
            location: location,
            createdAt: Date()
        )

        draftStore.saveTransaction(transaction)
        showLiveActivityIfNeeded(for: transaction)
        resetFormForNextTransaction()
        draftStore.clearMessage()
        selectedTab = .transactions
    }

    private func saveBatchTransactions() {
        draftStore.clearMessage()

        guard selectedKind != .transfer else {
            errorKey = "record.batch.error.transferUnsupported"
            return
        }

        guard let normalizedAmount = normalizedPositiveAmountText(amountText) else {
            errorKey = "record.error.invalidAmount"
            return
        }

        guard !selectedCategoryId.isEmpty else {
            errorKey = "record.error.categoryRequired"
            return
        }

        guard !selectedAccountId.isEmpty else {
            errorKey = "record.error.accountRequired"
            return
        }

        let selectedDates = batchDates()
        guard !selectedDates.isEmpty else {
            errorKey = "record.batch.error.noDates"
            return
        }

        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let createdAt = Date()
        let transactions = selectedDates.enumerated().map { offset, transactionDate in
            DraftTransaction(
                id: UUID().uuidString,
                kind: selectedKind,
                amountText: normalizedAmount,
                transferInAmountText: nil,
                categoryId: selectedCategoryId,
                accountId: selectedAccountId,
                fromAccountId: nil,
                toAccountId: nil,
                date: transactionDate,
                note: trimmedNote,
                location: location,
                createdAt: createdAt.addingTimeInterval(TimeInterval(offset) / 1000)
            )
        }

        guard draftStore.saveTransactions(transactions) > 0 else {
            errorKey = "record.batch.error.saveFailed"
            return
        }

        resetFormForNextTransaction()
        draftStore.clearMessage()
        selectedTab = .transactions
    }

    private func showLiveActivityIfNeeded(for transaction: DraftTransaction) {
        let categoryName = draftStore.categoryDisplayName(for: transaction.categoryId)

        if RecentTransactionLiveActivityManager.isBudgetFeatureEnabled {
            if
                transaction.kind == .expense,
                let usage = draftStore.budgetUsageForRecentExpense(
                    transaction,
                    preferredBudgetId: RecentTransactionLiveActivityManager.selectedBudgetId
                )
            {
                RecentTransactionLiveActivityManager.showBudgetUsage(
                    usage: usage,
                    transaction: transaction,
                    transactionTitle: categoryName
                )
                return
            }
        }

        if RecentTransactionLiveActivityManager.isBudgetFeatureEnabled {
            RecentTransactionLiveActivityManager.showRecentTransactionFallback(
                transaction,
                accounts: draftStore.accounts,
                categoryName: categoryName
            )
            return
        }

        RecentTransactionLiveActivityManager.showRecentTransaction(
            transaction,
            accounts: draftStore.accounts,
            categoryName: categoryName
        )
    }

    private func resetFormForNextTransaction() {
        selectedKind = .expense
        entryMode = .single
        amountText = ""
        transferInAmountText = ""
        date = Date()
        note = ""
        location = nil
        batchDateComponents = []
        isLocating = false
        locationCaptureToken += 1
        locationMessageKey = nil
        errorKey = nil
        normalizeSelections()
    }

    private func captureLocation() {
        guard !isLocating else { return }

        locationCaptureToken += 1
        let currentLocationCaptureToken = locationCaptureToken
        isLocating = true
        locationMessageKey = "record.location.locating"

        Task {
            do {
                let capturedLocation = try await locationProvider.captureLocation()
                guard locationCaptureToken == currentLocationCaptureToken else { return }
                location = capturedLocation
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

    private func ensureBatchDateSelectionIfNeeded() {
        guard isBatchEntry, batchDateComponents.isEmpty else { return }
        batchDateComponents = [dateComponents(for: date)]
    }

    private func batchDates() -> [Date] {
        let calendar = Calendar.current
        let timeComponents = calendar.dateComponents([.hour, .minute, .second], from: date)
        return batchDateComponents
            .compactMap { components in
                guard let day = calendar.date(from: components) else { return nil }
                var dateComponents = calendar.dateComponents([.year, .month, .day], from: day)
                dateComponents.hour = timeComponents.hour
                dateComponents.minute = timeComponents.minute
                dateComponents.second = timeComponents.second ?? 0
                return calendar.date(from: dateComponents)
            }
            .sorted()
    }

    private func dateComponents(for date: Date) -> DateComponents {
        Calendar.current.dateComponents([.calendar, .era, .year, .month, .day], from: date)
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

private enum RecordEntryMode: String, CaseIterable, Identifiable {
    case single
    case batch

    var id: String { rawValue }

    var titleKey: LocalizedStringKey {
        switch self {
        case .single:
            return "record.entryMode.single"
        case .batch:
            return "record.entryMode.batch"
        }
    }
}

private struct RecordVisualSelectionItem: Identifiable, Equatable {
    let id: String
    let name: String
    let iconName: String
    let colorHex: String
    var subtitle: String = ""
    var depth: Int = 1
}

private struct RecordTemplateSelectionPage: View {
    let templates: [DraftTransactionTemplate]
    let categoryItem: (String) -> RecordVisualSelectionItem
    let categoryName: (String?) -> String
    let accountName: (String?) -> String
    let onSelect: (DraftTransactionTemplate) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private var filteredTemplates: [DraftTransactionTemplate] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return templates }

        return templates.filter { template in
            template.name.localizedCaseInsensitiveContains(query)
                || template.note.localizedCaseInsensitiveContains(query)
                || categoryName(template.categoryId).localizedCaseInsensitiveContains(query)
                || accountName(template.accountId).localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        List {
            if filteredTemplates.isEmpty {
                ContentUnavailableView(
                    "record.templates.search.empty.title",
                    systemImage: "magnifyingglass",
                    description: Text("record.templates.search.empty.subtitle")
                )
            } else {
                ForEach(filteredTemplates) { template in
                    Button {
                        onSelect(template)
                        dismiss()
                    } label: {
                        RecordTemplateRow(
                            template: template,
                            categoryItem: categoryItem(template.categoryId),
                            accountName: accountName(template.accountId)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .navigationTitle(Text("record.templates.choose.title"))
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: Text("record.templates.search.placeholder"))
    }
}

private struct RecordTemplateRow: View {
    let template: DraftTransactionTemplate
    let categoryItem: RecordVisualSelectionItem
    let accountName: String

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
            DraftVisualBadge(iconName: categoryItem.iconName, colorHex: categoryItem.colorHex, size: 30)

            VStack(alignment: .leading, spacing: 3) {
                Text(template.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                HStack(spacing: 5) {
                    Text(categoryItem.name)

                    Text("·")

                    Text(accountName)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }

            Spacer(minLength: 12)

            Text(amountText)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(amountColor)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .contentShape(Rectangle())
        .padding(.vertical, 3)
    }
}

struct RecordAmountInputRow: View {
    let placeholderKey: LocalizedStringKey
    @Binding var amountText: String
    let currencySymbol: String
    let tint: Color

    private var sanitizedAmountText: Binding<String> {
        Binding(
            get: { amountText },
            set: { newValue in
                guard DraftAmountFormatter.canAcceptNumericAmountInput(newValue) else { return }
                amountText = newValue
            }
        )
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(currencySymbol)
                .font(.title2.weight(.bold))
                .foregroundStyle(tint)

            TextField(placeholderKey, text: sanitizedAmountText)
                .keyboardType(.decimalPad)
                .font(.system(.largeTitle, design: .rounded).weight(.bold))
                .foregroundStyle(tint)
                .minimumScaleFactor(0.7)
        }
        .padding(.vertical, 6)
    }
}

private struct RecordVisualSelectionRow: View {
    let titleKey: LocalizedStringKey
    let item: RecordVisualSelectionItem

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

private struct RecordVisualSelectionPage: View {
    let titleKey: LocalizedStringKey
    let items: [RecordVisualSelectionItem]
    @Binding var selectedId: String
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private var filteredItems: [RecordVisualSelectionItem] {
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
    RecordPage(
        selectedTab: .constant(.record),
        requestedKind: .constant(nil)
    )
        .environmentObject(DraftBookkeepingStore())
        .environmentObject(ProfileStore())
}
