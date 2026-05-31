import MapKit
import SwiftUI
import UIKit

struct TransactionsPage: View {
    @EnvironmentObject private var draftStore: DraftBookkeepingStore
    @EnvironmentObject private var profileStore: ProfileStore
    @State private var editingTransaction: DraftTransaction?
    @State private var deletingTransaction: DraftTransaction?
    @State private var dateFilter = TransactionDateFilter()
    @State private var selectedAccountId: String?
    @State private var selectedCategoryId: String?
    @State private var hasInitializedDateFilter = false

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
                            hasActiveFilters: hasActiveFilters,
                            resetFilters: resetFilters
                        )
                    }
                    .listRowSeparator(.hidden)

                    Section {
                        if groupedTransactions.isEmpty {
                            TransactionEmptyFilteredView(hasActiveFilters: hasActiveFilters)
                                .padding(.vertical, 28)
                                .frame(maxWidth: .infinity)
                                .listRowSeparator(.hidden)
                        } else {
                            ForEach(groupedTransactions) { group in
                                VStack(spacing: 0) {
                                    TransactionDayHeader(
                                        date: group.date
                                    )
                                    .padding(.bottom, 8)

                                    ForEach(group.transactions) { transaction in
                                        TransactionSummaryCard(
                                            transaction: transaction,
                                            accountItem: accountItem(for: transaction),
                                            categoryItem: categoryItem(for: transaction),
                                            timeText: Self.timeFormatter.string(from: transaction.date),
                                            onEdit: {
                                                editingTransaction = transaction
                                            }
                                        )
                                        .padding(.vertical, 10)
                                        .overlay(alignment: .bottom) {
                                            if transaction.id != group.transactions.last?.id {
                                                Divider()
                                                    .padding(.leading, 58)
                                            }
                                        }
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
                                }
                                .padding(.vertical, 6)
                            }
                        }
                    } footer: {
                        Text("transactions.footer.localOnly")
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(Text("tab.transactions"))
            .onAppear {
                initializeDateFilterIfNeeded()
            }
            .onChange(of: draftStore.transactions) { _, _ in
                initializeDateFilterIfNeeded()
            }
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

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()
}

private struct TransactionDayGroup: Identifiable {
    let date: Date
    let transactions: [DraftTransaction]

    var id: Date { date }
}

private enum TransactionDateFilterMode: String, CaseIterable, Identifiable {
    case day
    case month
    case year
    case range

    var id: String { rawValue }

    var titleKey: LocalizedStringKey {
        switch self {
        case .day:
            return "transactions.date.mode.day"
        case .month:
            return "transactions.date.mode.month"
        case .year:
            return "transactions.date.mode.year"
        case .range:
            return "transactions.date.mode.range"
        }
    }

    var component: Calendar.Component {
        switch self {
        case .day, .range:
            return .day
        case .month:
            return .month
        case .year:
            return .year
        }
    }
}

private enum TransactionDateRangeUnit: String, CaseIterable, Identifiable {
    case day
    case month
    case year

    var id: String { rawValue }

    var titleKey: LocalizedStringKey {
        switch self {
        case .day:
            return "transactions.date.rangeUnit.day"
        case .month:
            return "transactions.date.rangeUnit.month"
        case .year:
            return "transactions.date.rangeUnit.year"
        }
    }

    var component: Calendar.Component {
        switch self {
        case .day:
            return .day
        case .month:
            return .month
        case .year:
            return .year
        }
    }
}

private struct TransactionDateFilter: Equatable {
    var mode: TransactionDateFilterMode = .month
    var rangeUnit: TransactionDateRangeUnit = .day
    var referenceDate: Date = Date()
    var rangeStart: Date = Date()
    var rangeEnd: Date = Date()

    func contains(_ date: Date, calendar: Calendar = .current) -> Bool {
        switch mode {
        case .day:
            return calendar.isDate(date, inSameDayAs: referenceDate)
        case .month:
            return calendar.isDate(date, equalTo: referenceDate, toGranularity: .month)
        case .year:
            return calendar.isDate(date, equalTo: referenceDate, toGranularity: .year)
        case .range:
            let interval = normalizedRangeInterval(calendar: calendar)
            return date >= interval.start && date < interval.end
        }
    }

    mutating func setReference(_ date: Date) {
        referenceDate = date
        rangeStart = date
        rangeEnd = date
    }

    mutating func shift(by value: Int, calendar: Calendar = .current) {
        switch mode {
        case .day:
            referenceDate = calendar.date(byAdding: .day, value: value, to: referenceDate) ?? referenceDate
        case .month:
            referenceDate = calendar.date(byAdding: .month, value: value, to: referenceDate) ?? referenceDate
        case .year:
            referenceDate = calendar.date(byAdding: .year, value: value, to: referenceDate) ?? referenceDate
        case .range:
            let component = rangeUnit.component
            rangeStart = calendar.date(byAdding: component, value: value, to: rangeStart) ?? rangeStart
            rangeEnd = calendar.date(byAdding: component, value: value, to: rangeEnd) ?? rangeEnd
        }
    }

    func summaryText(calendar: Calendar = .current) -> String {
        switch mode {
        case .day:
            return Self.dayFormatter.string(from: referenceDate)
        case .month:
            return Self.monthFormatter.string(from: referenceDate)
        case .year:
            return Self.yearFormatter.string(from: referenceDate)
        case .range:
            let interval = normalizedRangeBounds(calendar: calendar)
            return "\(rangeText(for: interval.start, unit: rangeUnit)) - \(rangeText(for: interval.end, unit: rangeUnit))"
        }
    }

    private func rangeText(for date: Date, unit: TransactionDateRangeUnit) -> String {
        switch unit {
        case .day:
            return Self.dayFormatter.string(from: date)
        case .month:
            return Self.monthFormatter.string(from: date)
        case .year:
            return Self.yearFormatter.string(from: date)
        }
    }

    private func normalizedRangeBounds(calendar: Calendar) -> (start: Date, end: Date) {
        if rangeStart <= rangeEnd {
            return (rangeStart, rangeEnd)
        }

        return (rangeEnd, rangeStart)
    }

    private func normalizedRangeInterval(calendar: Calendar) -> (start: Date, end: Date) {
        let bounds = normalizedRangeBounds(calendar: calendar)
        let start = startOfPeriod(for: bounds.start, component: rangeUnit.component, calendar: calendar)
        let endStart = startOfPeriod(for: bounds.end, component: rangeUnit.component, calendar: calendar)
        let end = calendar.date(byAdding: rangeUnit.component, value: 1, to: endStart) ?? endStart
        return (start, end)
    }

    private func startOfPeriod(for date: Date, component: Calendar.Component, calendar: Calendar) -> Date {
        switch component {
        case .day:
            return calendar.startOfDay(for: date)
        case .month:
            let components = calendar.dateComponents([.year, .month], from: date)
            return calendar.date(from: components) ?? date
        case .year:
            let components = calendar.dateComponents([.year], from: date)
            return calendar.date(from: components) ?? date
        default:
            return date
        }
    }

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = DateFormatter.dateFormat(fromTemplate: "yMMMd", options: 0, locale: .current)
        return formatter
    }()

    private static let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = DateFormatter.dateFormat(fromTemplate: "yMMMM", options: 0, locale: .current)
        return formatter
    }()

    private static let yearFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = DateFormatter.dateFormat(fromTemplate: "y", options: 0, locale: .current)
        return formatter
    }()
}

private struct TransactionDateHeader: View {
    @Binding var dateFilter: TransactionDateFilter
    let onPrevious: () -> Void
    let onNext: () -> Void
    @State private var isDatePickerPresented = false

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onPrevious) {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.semibold))
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(Text("transactions.date.previous"))

            Button {
                isDatePickerPresented = true
            } label: {
                Text(dateFilter.summaryText())
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(maxWidth: .infinity, minHeight: 36)
                    .padding(.horizontal, 12)
                    .background(Capsule().fill(Color.secondary.opacity(0.12)))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("transactions.date.filter"))

            Button(action: onNext) {
                Image(systemName: "chevron.right")
                    .font(.body.weight(.semibold))
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(Text("transactions.date.next"))
        }
        .padding(.vertical, 4)
        .sheet(isPresented: $isDatePickerPresented) {
            TransactionDateFilterSheet(dateFilter: $dateFilter)
                .presentationDetents([.large])
        }
    }
}

private struct TransactionDateFilterSheet: View {
    @Binding var dateFilter: TransactionDateFilter
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("transactions.date.mode", selection: $dateFilter.mode) {
                        ForEach(TransactionDateFilterMode.allCases) { mode in
                            Text(mode.titleKey).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                if dateFilter.mode == .range {
                    Section {
                        Picker("transactions.date.rangeUnit", selection: $dateFilter.rangeUnit) {
                            ForEach(TransactionDateRangeUnit.allCases) { unit in
                                Text(unit.titleKey).tag(unit)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    Section {
                        DatePicker(
                            "transactions.date.rangeStart",
                            selection: $dateFilter.rangeStart,
                            displayedComponents: .date
                        )

                        DatePicker(
                            "transactions.date.rangeEnd",
                            selection: $dateFilter.rangeEnd,
                            displayedComponents: .date
                        )
                    }
                } else {
                    Section {
                        DatePicker(
                            "transactions.date.value",
                            selection: $dateFilter.referenceDate,
                            displayedComponents: .date
                        )
                        .datePickerStyle(.graphical)
                    }
                }
            }
            .navigationTitle(Text("transactions.date.filter"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct TransactionFilterBar: View {
    @Binding var selectedAccountId: String?
    @Binding var selectedCategoryId: String?
    let accounts: [DraftAccount]
    let categories: [DraftCategory]
    let hasActiveFilters: Bool
    let resetFilters: () -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Menu {
                    Button("transactions.filter.allAccounts") {
                        selectedAccountId = nil
                    }

                    ForEach(accounts) { account in
                        Button(archivedAwareName(account.name, isArchived: account.isArchived)) {
                            selectedAccountId = account.id
                        }
                    }
                } label: {
                    TransactionFilterPill(
                        title: accountTitle,
                        systemImage: "creditcard",
                        isActive: selectedAccountId != nil
                    )
                }

                Menu {
                    Button("transactions.filter.allCategories") {
                        selectedCategoryId = nil
                    }

                    ForEach(categories) { category in
                        Button(archivedAwareName(category.name, isArchived: category.isArchived)) {
                            selectedCategoryId = category.id
                        }
                    }
                } label: {
                    TransactionFilterPill(
                        title: categoryTitle,
                        systemImage: "tag",
                        isActive: selectedCategoryId != nil
                    )
                }

                if hasActiveFilters {
                    Button(action: resetFilters) {
                        TransactionFilterPill(
                            title: NSLocalizedString("transactions.filter.reset", comment: ""),
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
        guard
            let selectedAccountId,
            let account = accounts.first(where: { $0.id == selectedAccountId })
        else {
            return NSLocalizedString("transactions.filter.allAccounts", comment: "")
        }

        return archivedAwareName(account.name, isArchived: account.isArchived)
    }

    private var categoryTitle: String {
        guard
            let selectedCategoryId,
            let category = categories.first(where: { $0.id == selectedCategoryId })
        else {
            return NSLocalizedString("transactions.filter.allCategories", comment: "")
        }

        return archivedAwareName(category.name, isArchived: category.isArchived)
    }

    private func archivedAwareName(_ name: String, isArchived: Bool) -> String {
        guard isArchived else { return name }
        return String(format: NSLocalizedString("draft.item.archivedFormat", comment: ""), name)
    }
}

private struct TransactionFilterPill: View {
    let title: String
    let systemImage: String
    let isActive: Bool

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .lineLimit(1)
            .foregroundStyle(isActive ? Color.accentColor : .primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(isActive ? Color.accentColor.opacity(0.14) : Color.secondary.opacity(0.12))
            )
    }
}

private struct TransactionDayHeader: View {
    let date: Date

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(Self.dayFormatter.string(from: date))
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.primary)

                Text(Self.weekdayFormatter.string(from: date))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 44, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                Text(Self.fullDateFormatter.string(from: date))
                    .font(.subheadline.weight(.semibold))
            }

            Spacer()
        }
    }

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter
    }()

    private static let weekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter
    }()

    private static let fullDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = DateFormatter.dateFormat(fromTemplate: "yMMMd", options: 0, locale: .current)
        return formatter
    }()
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

private struct TransactionSummaryCard: View {
    let transaction: DraftTransaction
    let accountItem: DraftVisualSummaryItem
    let categoryItem: DraftVisualSummaryItem
    let timeText: String
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
        Button(action: onEdit) {
            HStack(alignment: .center, spacing: 12) {
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

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
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
                    format: NSLocalizedString("transactions.location.openInMaps.accessibility", comment: ""),
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
