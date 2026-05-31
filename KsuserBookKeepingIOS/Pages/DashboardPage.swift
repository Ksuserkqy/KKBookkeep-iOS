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

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    dashboardHeader
                    balanceCard
                    monthOverviewSection
                    quickActionsSection
                    budgetSection
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
        DashboardSection(titleKey: "dashboard.monthOverview") {
            HStack(spacing: 10) {
                DashboardMetricTile(
                    titleKey: "dashboard.monthIncome",
                    value: currencyText(from: 0),
                    systemImage: "arrow.down.circle.fill",
                    tint: .green
                )

                DashboardMetricTile(
                    titleKey: "dashboard.monthExpense",
                    value: currencyText(from: 0),
                    systemImage: "arrow.up.circle.fill",
                    tint: .red
                )

                DashboardMetricTile(
                    titleKey: "dashboard.monthBalance",
                    value: currencyText(from: 0),
                    systemImage: "equal.circle.fill",
                    tint: .accentColor
                )
            }

            Text("dashboard.monthOverview.empty")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
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

    private var budgetSection: some View {
        DashboardSection(titleKey: "dashboard.budget") {
            DashboardCard {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 12) {
                        Image(systemName: "chart.pie.fill")
                            .font(.title3)
                            .foregroundStyle(.tint)
                            .frame(width: 36, height: 36)
                            .background(
                                Circle()
                                    .fill(Color.accentColor.opacity(0.14))
                            )

                        VStack(alignment: .leading, spacing: 4) {
                            Text("dashboard.budget.emptyTitle")
                                .font(.headline)

                            Text("dashboard.budget.emptySubtitle")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    ProgressView(value: 0, total: 1)
                        .tint(.accentColor)
                }
            }
        }
    }

    private var accountsSection: some View {
        DashboardSection(titleKey: "dashboard.accounts") {
            DashboardCard {
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

    @ViewBuilder
    private var recentDraftSection: some View {
        DashboardSection(titleKey: "dashboard.recentDraft") {
            DashboardCard {
                if let draft = draftStore.lastDraft {
                    DashboardDraftSummary(
                        draft: draft,
                        accountName: accountName(for: draft),
                        categoryName: categoryName(for: draft)
                    )
                } else {
                    DashboardEmptyState(
                        systemImage: "doc.badge.clock",
                        titleKey: "dashboard.recentDraft.emptyTitle",
                        subtitleKey: "dashboard.recentDraft.emptySubtitle"
                    )
                }
            }
        }
    }

    private func accountName(for draft: DraftTransaction) -> String {
        switch draft.kind {
        case .expense, .income:
            return draftStore.accountName(for: draft.accountId)
        case .transfer:
            let fromAccount = draftStore.accountName(for: draft.fromAccountId)
            let toAccount = draftStore.accountName(for: draft.toAccountId)
            return String(
                format: NSLocalizedString("dashboard.transferAccountFormat", comment: ""),
                fromAccount,
                toAccount
            )
        }
    }

    private func categoryName(for draft: DraftTransaction) -> String {
        switch draft.kind {
        case .expense, .income:
            return draftStore.categoryName(for: draft.categoryId)
        case .transfer:
            return NSLocalizedString("record.kind.transfer", comment: "")
        }
    }

    private func decimalValue(from text: String) -> Decimal {
        let normalizedText = DraftAmountFormatter.normalizedAmountText(text, allowNegative: true) ?? "0"
        return Decimal(string: normalizedText, locale: Locale(identifier: "en_US_POSIX")) ?? 0
    }

    private func currencyText(from decimal: Decimal) -> String {
        DraftAmountFormatter.currencyText(from: NSDecimalNumber(decimal: decimal).stringValue)
    }
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

private struct DashboardDraftSummary: View {
    let draft: DraftTransaction
    let accountName: String
    let categoryName: String

    private var amountText: String {
        switch draft.kind {
        case .expense, .income:
            return DraftAmountFormatter.currencyText(from: draft.amountText)
        case .transfer:
            return DraftAmountFormatter.currencyText(from: draft.amountText)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(LocalizedStringKey(draft.kind.localizationKey))
                        .font(.headline)

                    Text(categoryName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 12)

                Text(amountText)
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }

            HStack(spacing: 8) {
                Image(systemName: "creditcard.fill")
                    .foregroundStyle(.secondary)

                Text(accountName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer(minLength: 8)

                Text(Self.dateFormatter.string(from: draft.date))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let location = draft.location {
                HStack(spacing: 8) {
                    Image(systemName: "location.fill")
                        .foregroundStyle(.secondary)

                    Text(location.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
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
