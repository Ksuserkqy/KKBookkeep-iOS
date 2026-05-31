import SwiftUI

struct DashboardPage: View {
    @EnvironmentObject private var draftStore: DraftBookkeepingStore
    @Binding var selectedTab: AppTab
    @Binding var requestedRecordKind: DraftEntryKind?

    private var totalBalanceText: String {
        let total = draftStore.accounts.filter { !$0.isArchived }.reduce(Decimal(0)) { partialResult, account in
            partialResult + decimalValue(from: account.balanceText)
        }

        return currencyText(from: total)
    }

    private var displayedAccounts: [DraftAccount] {
        Array(draftStore.accounts.filter { !$0.isArchived }.prefix(3))
    }

    private var recentTransactions: [DraftTransaction] {
        Array(draftStore.transactions.prefix(3))
    }

    private var monthSummary: DashboardMonthSummary {
        let calendar = Calendar.current
        let now = Date()
        let monthInterval = calendar.dateInterval(of: .month, for: now)
        let dayInterval = calendar.dateInterval(of: .day, for: now)
        var income = Decimal(0)
        var expense = Decimal(0)
        var todayExpense = Decimal(0)
        var expenseByCategory: [String: Decimal] = [:]
        var transactionCount = 0

        for transaction in draftStore.transactions {
            if let monthInterval, monthInterval.contains(transaction.date) {
                transactionCount += 1

                switch transaction.kind {
                case .income:
                    income += decimalValue(from: transaction.amountText)
                case .expense:
                    let amount = decimalValue(from: transaction.amountText)
                    expense += amount

                    if let categoryId = transaction.categoryId {
                        expenseByCategory[categoryId, default: 0] += amount
                    }
                case .transfer:
                    break
                }
            }

            if
                transaction.kind == .expense,
                let dayInterval,
                dayInterval.contains(transaction.date)
            {
                todayExpense += decimalValue(from: transaction.amountText)
            }
        }

        let topCategory = expenseByCategory.max { lhs, rhs in
            if lhs.value == rhs.value {
                return categoryDisplayName(for: lhs.key) > categoryDisplayName(for: rhs.key)
            }

            return lhs.value < rhs.value
        }

        return DashboardMonthSummary(
            income: income,
            expense: expense,
            balance: income - expense,
            todayExpense: todayExpense,
            transactionCount: transactionCount,
            topExpenseCategoryName: topCategory.map { categoryDisplayName(for: $0.key) },
            topExpenseCategoryAmount: topCategory?.value
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    dashboardHeader
                    balanceCard
                    monthOverviewSection
                    quickActionsSection
                    accountsSection
                    recentDraftSection
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 28)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(Text("tab.dashboard"))
        }
    }

    private var dashboardHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("dashboard.greeting")
                .font(.title2.weight(.semibold))

            Text("dashboard.subtitle")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var balanceCard: some View {
        DashboardCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .center, spacing: 12) {
                    Image(systemName: "wallet.pass.fill")
                        .font(.title2)
                        .foregroundStyle(.tint)
                        .frame(width: 40, height: 40)
                        .background(
                            Circle()
                                .fill(Color.accentColor.opacity(0.16))
                        )

                    VStack(alignment: .leading, spacing: 4) {
                        Text("dashboard.totalBalance")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Text(totalBalanceText)
                            .font(.system(.largeTitle, design: .rounded).weight(.bold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                    }

                    Spacer(minLength: 0)
                }

                Text("dashboard.totalBalance.footer")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var monthOverviewSection: some View {
        let summary = monthSummary

        return DashboardSection(titleKey: "dashboard.monthOverview") {
            HStack(spacing: 10) {
                DashboardMetricTile(
                    titleKey: "dashboard.monthIncome",
                    value: currencyText(from: summary.income),
                    systemImage: "arrow.down.circle.fill",
                    tint: .green
                )

                DashboardMetricTile(
                    titleKey: "dashboard.monthExpense",
                    value: currencyText(from: summary.expense),
                    systemImage: "arrow.up.circle.fill",
                    tint: .red
                )

                DashboardMetricTile(
                    titleKey: "dashboard.monthBalance",
                    value: currencyText(from: summary.balance),
                    systemImage: "equal.circle.fill",
                    tint: .accentColor
                )
            }

            DashboardCard {
                VStack(spacing: 12) {
                    DashboardFactRow(
                        titleKey: "dashboard.todayExpense",
                        value: currencyText(from: summary.todayExpense),
                        systemImage: "calendar.badge.clock",
                        tint: .orange
                    )

                    Divider()

                    DashboardFactRow(
                        titleKey: "dashboard.monthTransactions",
                        value: String(
                            format: NSLocalizedString("dashboard.monthTransactions.valueFormat", comment: ""),
                            summary.transactionCount
                        ),
                        systemImage: "list.bullet.rectangle.portrait.fill",
                        tint: .blue
                    )

                    if let topExpenseCategoryName = summary.topExpenseCategoryName,
                       let topExpenseCategoryAmount = summary.topExpenseCategoryAmount {
                        Divider()

                        DashboardFactRow(
                            titleKey: "dashboard.topExpenseCategory",
                            value: String(
                                format: NSLocalizedString("dashboard.topExpenseCategory.valueFormat", comment: ""),
                                topExpenseCategoryName,
                                currencyText(from: topExpenseCategoryAmount)
                            ),
                            systemImage: "chart.bar.xaxis",
                            tint: .purple
                        )
                    }
                }
            }
        }
    }

    private var quickActionsSection: some View {
        DashboardSection(titleKey: "dashboard.quickActions") {
            HStack(spacing: 10) {
                DashboardQuickActionButton(
                    titleKey: "dashboard.quickExpense",
                    systemImage: "minus.circle.fill",
                    tint: .red
                ) {
                    requestedRecordKind = .expense
                    selectedTab = .record
                }

                DashboardQuickActionButton(
                    titleKey: "dashboard.quickIncome",
                    systemImage: "plus.circle.fill",
                    tint: .green
                ) {
                    requestedRecordKind = .income
                    selectedTab = .record
                }

                DashboardQuickActionButton(
                    titleKey: "dashboard.quickTransfer",
                    systemImage: "arrow.left.arrow.right.circle.fill",
                    tint: .blue
                ) {
                    requestedRecordKind = .transfer
                    selectedTab = .record
                }
            }
        }
    }

    private var accountsSection: some View {
        DashboardSection(titleKey: "dashboard.accounts") {
            DashboardCard {
                if displayedAccounts.isEmpty {
                    DashboardEmptyState(
                        systemImage: "wallet.pass",
                        titleKey: "dashboard.accounts.emptyTitle",
                        subtitleKey: "dashboard.accounts.emptySubtitle"
                    )
                } else {
                    VStack(spacing: 0) {
                        ForEach(displayedAccounts) { account in
                            DashboardAccountRow(account: account)

                            if account.id != displayedAccounts.last?.id {
                                Divider()
                                    .padding(.leading, 46)
                                    .padding(.vertical, 10)
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var recentDraftSection: some View {
        DashboardSection(titleKey: "dashboard.recentDraft") {
            DashboardCard {
                if recentTransactions.isEmpty {
                    DashboardEmptyState(
                        systemImage: "doc.badge.clock",
                        titleKey: "dashboard.recentDraft.emptyTitle",
                        subtitleKey: "dashboard.recentDraft.emptySubtitle"
                    )
                } else {
                    VStack(spacing: 0) {
                        ForEach(recentTransactions) { transaction in
                            DashboardTransactionRow(
                                transaction: transaction,
                                accountName: accountName(for: transaction),
                                categoryItem: categoryItem(for: transaction)
                            )

                            if transaction.id != recentTransactions.last?.id {
                                Divider()
                                    .padding(.leading, 46)
                                    .padding(.vertical, 10)
                            }
                        }
                    }
                }
            }
        }
    }

    private func accountName(for draft: DraftTransaction) -> String {
        switch draft.kind {
        case .expense, .income:
            return accountDisplayName(for: draft.accountId)
        case .transfer:
            let fromAccount = accountDisplayName(for: draft.fromAccountId)
            let toAccount = accountDisplayName(for: draft.toAccountId)
            return String(
                format: NSLocalizedString("dashboard.transferAccountFormat", comment: ""),
                fromAccount,
                toAccount
            )
        }
    }

    private func categoryItem(for draft: DraftTransaction) -> DashboardVisualItem {
        switch draft.kind {
        case .expense, .income:
            guard
                let categoryId = draft.categoryId,
                let category = draftStore.categories.first(where: { $0.id == categoryId })
            else {
                return DashboardVisualItem(
                    name: NSLocalizedString("draft.item.missing", comment: ""),
                    iconName: "circle-question",
                    colorHex: "#64748B"
                )
            }

            return DashboardVisualItem(
                name: archivedAwareName(categoryDisplayName(for: category.id), isArchived: category.isArchived),
                iconName: category.iconName,
                colorHex: category.colorHex
            )
        case .transfer:
            return DashboardVisualItem(
                name: NSLocalizedString("record.kind.transfer", comment: ""),
                iconName: "right-left",
                colorHex: "#3B82F6"
            )
        }
    }

    private func accountDisplayName(for id: String?) -> String {
        guard
            let id,
            let account = draftStore.accounts.first(where: { $0.id == id })
        else {
            return NSLocalizedString("draft.item.missing", comment: "")
        }

        return archivedAwareName(account.name, isArchived: account.isArchived)
    }

    private func categoryDisplayName(for id: String) -> String {
        let name = draftStore.categoryDisplayName(for: id)
        let isArchived = draftStore.categories.first(where: { $0.id == id })?.isArchived ?? false
        return archivedAwareName(name, isArchived: isArchived)
    }

    private func archivedAwareName(_ name: String, isArchived: Bool) -> String {
        guard isArchived else { return name }
        return String(format: NSLocalizedString("draft.item.archivedFormat", comment: ""), name)
    }

    private func decimalValue(from text: String) -> Decimal {
        let normalizedText = DraftAmountFormatter.normalizedAmountText(text, allowNegative: true) ?? "0"
        return Decimal(string: normalizedText, locale: Locale(identifier: "en_US_POSIX")) ?? 0
    }

    private func currencyText(from decimal: Decimal) -> String {
        DraftAmountFormatter.currencyText(from: NSDecimalNumber(decimal: decimal).stringValue)
    }
}

private struct DashboardMonthSummary {
    let income: Decimal
    let expense: Decimal
    let balance: Decimal
    let todayExpense: Decimal
    let transactionCount: Int
    let topExpenseCategoryName: String?
    let topExpenseCategoryAmount: Decimal?
}

private struct DashboardVisualItem {
    let name: String
    let iconName: String
    let colorHex: String
}

private struct DashboardSection<Content: View>: View {
    let titleKey: LocalizedStringKey
    let content: Content

    init(titleKey: LocalizedStringKey, @ViewBuilder content: () -> Content) {
        self.titleKey = titleKey
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(titleKey)
                .font(.headline)

            content
        }
    }
}

private struct DashboardCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct DashboardFactRow: View {
    let titleKey: LocalizedStringKey
    let value: String
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 30, height: 30)
                .background(
                    Circle()
                        .fill(tint.opacity(0.14))
                )

            Text(titleKey)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer(minLength: 12)

            Text(value)
                .font(.subheadline.weight(.semibold))
                .multilineTextAlignment(.trailing)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
    }
}

private struct DashboardMetricTile: View {
    let titleKey: LocalizedStringKey
    let value: String
    let systemImage: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: systemImage)
                .font(.headline)
                .foregroundStyle(tint)

            Text(titleKey)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.82)

            Text(value)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 104)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct DashboardQuickActionButton: View {
    let titleKey: LocalizedStringKey
    let systemImage: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.title3)
                    .foregroundStyle(tint)

                Text(titleKey)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .frame(height: 82)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(titleKey))
    }
}

private struct DashboardAccountRow: View {
    let account: DraftAccount

    var body: some View {
        HStack(spacing: 12) {
            DraftVisualBadge(iconName: account.iconName, colorHex: account.colorHex, size: 34)

            VStack(alignment: .leading, spacing: 3) {
                Text(account.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)

                Text(account.type.titleKey)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            Text(DraftAmountFormatter.currencyText(from: account.balanceText))
                .font(.subheadline.weight(.semibold))
                .multilineTextAlignment(.trailing)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
    }
}

private struct DashboardTransactionRow: View {
    let transaction: DraftTransaction
    let accountName: String
    let categoryItem: DashboardVisualItem

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
        HStack(alignment: .center, spacing: 12) {
            DraftVisualBadge(iconName: categoryItem.iconName, colorHex: categoryItem.colorHex, size: 34)

            VStack(alignment: .leading, spacing: 5) {
                Text(categoryItem.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)

                HStack(spacing: 5) {
                    Text(LocalizedStringKey(transaction.kind.localizationKey))

                    Text("·")

                    Text(accountName)

                    if let location = transaction.location {
                        Text("·")

                        Image(systemName: "location.fill")
                            .accessibilityLabel(Text(location.displayName))
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

                if !transaction.note.isEmpty {
                    Text(transaction.note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 12)

            VStack(alignment: .trailing, spacing: 5) {
                Text(amountText)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(amountColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)

                Text(Self.dateFormatter.string(from: transaction.date))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}

private struct DashboardEmptyState: View {
    let systemImage: String
    let titleKey: LocalizedStringKey
    let subtitleKey: LocalizedStringKey

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 4) {
                Text(titleKey)
                    .font(.subheadline.weight(.semibold))

                Text(subtitleKey)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

#Preview {
    DashboardPage(
        selectedTab: .constant(.dashboard),
        requestedRecordKind: .constant(nil)
    )
        .environmentObject(DraftBookkeepingStore())
}
