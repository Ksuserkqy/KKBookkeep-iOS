import Charts
import SwiftUI

struct ReportsPage: View {
    @EnvironmentObject private var draftStore: DraftBookkeepingStore
    @State private var dateFilter = TransactionDateFilter()
    @State private var hasInitializedDateFilter = false

    private var reportData: ReportData {
        makeReportData(for: dateFilter)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    dateFilterSection
                    periodContext
                    summaryGrid
                    trendSection
                    paceSection
                    breakdownOptionsSection
                    insightsSection
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 18)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(Text("tab.reports"))
            .onAppear {
                initializeDateFilterIfNeeded()
            }
            .onChange(of: draftStore.transactions) { _, _ in
                initializeDateFilterIfNeeded()
            }
        }
    }

    private var dateFilterSection: some View {
        ReportCard {
            TransactionDateHeader(
                dateFilter: $dateFilter,
                onPrevious: { dateFilter.shift(by: -1) },
                onNext: { dateFilter.shift(by: 1) }
            )
        }
    }

    private var breakdownOptionsSection: some View {
        ReportCard {
            VStack(alignment: .leading, spacing: 16) {
                ReportSectionHeader(
                    titleKey: "reports.breakdown.title",
                    subtitleKey: "reports.breakdown.subtitle",
                    systemImage: "square.grid.2x2.fill"
                )

                VStack(spacing: 0) {
                    ForEach(reportData.rankingSections.indices, id: \.self) { index in
                        let section = reportData.rankingSections[index]

                        NavigationLink {
                            ReportRankingDetailPage(section: section)
                        } label: {
                            ReportRankingOptionRow(section: section)
                        }
                        .buttonStyle(.plain)

                        if index < reportData.rankingSections.count - 1 {
                            Divider()
                                .padding(.leading, 42)
                        }
                    }
                }
            }
        }
    }

    private var periodContext: some View {
        ReportContextBar(
            rangeText: reportData.periodRangeText,
            summaryText: reportData.periodSummaryText
        )
    }

    private var summaryGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 136), spacing: 12)], spacing: 12) {
            ForEach(reportData.summaryMetrics) { metric in
                ReportMetricCard(metric: metric)
            }
        }
    }

    private var trendSection: some View {
        ReportCard {
            VStack(alignment: .leading, spacing: 16) {
                ReportSectionHeader(
                    titleKey: "reports.trend.title",
                    subtitleKey: "reports.trend.subtitle.filtered",
                    systemImage: "chart.xyaxis.line"
                )

                if reportData.trendPoints.contains(where: { $0.expense > 0 || $0.income > 0 }) {
                    Chart {
                        ForEach(reportData.trendPoints) { point in
                            BarMark(
                                x: .value(Self.localizedChartLabel("reports.chart.axis.date"), point.label),
                                y: .value(Self.localizedChartLabel("reports.chart.axis.expense"), point.expense)
                            )
                            .foregroundStyle(Color.accentColor.gradient)
                            .cornerRadius(5)

                            LineMark(
                                x: .value(Self.localizedChartLabel("reports.chart.axis.date"), point.label),
                                y: .value(Self.localizedChartLabel("reports.chart.axis.income"), point.income)
                            )
                            .foregroundStyle(Color.green)
                            .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))

                            PointMark(
                                x: .value(Self.localizedChartLabel("reports.chart.axis.date"), point.label),
                                y: .value(Self.localizedChartLabel("reports.chart.axis.income"), point.income)
                            )
                            .foregroundStyle(Color.green)
                        }
                    }
                    .chartLegend(.hidden)
                    .chartYAxis {
                        AxisMarks(position: .leading) { value in
                            AxisGridLine()
                            AxisValueLabel {
                                if let amount = value.as(Double.self) {
                                    Text(Self.compactCurrencyFormatter.string(from: amount as NSNumber) ?? "")
                                }
                            }
                        }
                    }
                    .frame(height: 180)
                } else {
                    ReportEmptyState(
                        systemImage: "chart.bar.xaxis",
                        titleKey: "reports.empty.trend.title",
                        subtitleKey: "reports.empty.trend.subtitle"
                    )
                }

                HStack(spacing: 14) {
                    ChartLegendDot(color: .accentColor, titleKey: "reports.legend.expense")
                    ChartLegendDot(color: .green, titleKey: "reports.legend.income")
                }
            }
        }
    }

    private var paceSection: some View {
        ReportCard {
            VStack(alignment: .leading, spacing: 16) {
                ReportSectionHeader(
                    titleKey: "reports.pace.title",
                    subtitleKey: "reports.pace.subtitle",
                    systemImage: "waveform.path.ecg"
                )

                if reportData.paceHighlights.isEmpty {
                    ReportEmptyState(
                        systemImage: "calendar.badge.clock",
                        titleKey: "reports.empty.pace.title",
                        subtitleKey: "reports.empty.pace.subtitle"
                    )
                } else {
                    VStack(spacing: 0) {
                        ForEach(reportData.paceHighlights.indices, id: \.self) { index in
                            let highlight = reportData.paceHighlights[index]
                            ReportHighlightRow(highlight: highlight)

                            if index < reportData.paceHighlights.count - 1 {
                                Divider()
                                    .padding(.leading, 42)
                            }
                        }
                    }
                }
            }
        }
    }

    private var insightsSection: some View {
        ReportCard {
            VStack(alignment: .leading, spacing: 14) {
                ReportSectionHeader(
                    titleKey: "reports.insights.title",
                    subtitleKey: "reports.insights.subtitle",
                    systemImage: "sparkles"
                )

                VStack(spacing: 12) {
                    ForEach(reportData.insights) { insight in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: insight.systemImage)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(insight.color)
                                .frame(width: 24, height: 24)
                                .background(insight.color.opacity(0.14), in: Circle())

                            VStack(alignment: .leading, spacing: 4) {
                                Text(insight.title)
                                    .font(.subheadline.weight(.semibold))

                                Text(insight.subtitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            Spacer(minLength: 0)
                        }
                    }
                }
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

    private func makeReportData(for dateFilter: TransactionDateFilter) -> ReportData {
        let calendar = Calendar.current
        let now = Date()
        let interval = dateFilter.dateInterval(calendar: calendar)
        let previousInterval = dateFilter.previousDateInterval(calendar: calendar)
        let periodName = dateFilter.summaryText(calendar: calendar)
        var income = Decimal(0)
        var expense = Decimal(0)
        var previousExpense = Decimal(0)
        var previousIncome = Decimal(0)
        var dailyExpenses: [Date: Decimal] = [:]
        var entryCount = 0
        var transferCount = 0
        var accountOutflowTotals: [String: Decimal] = [:]
        var accountExpenseTotals: [String: Decimal] = [:]
        var primaryExpenseCategoryTotals: [String: Decimal] = [:]
        var secondaryExpenseCategoryTotals: [String: Decimal] = [:]
        var accountInflowTotals: [String: Decimal] = [:]
        var accountIncomeTotals: [String: Decimal] = [:]
        var primaryIncomeCategoryTotals: [String: Decimal] = [:]
        var secondaryIncomeCategoryTotals: [String: Decimal] = [:]
        var trendBuckets = makeTrendBuckets(in: interval, calendar: calendar)

        for transaction in draftStore.transactions {
            if contains(transaction.date, in: interval) {
                switch transaction.kind {
                case .expense:
                    let amount = decimalValue(from: transaction.amountText)
                    expense += amount
                    entryCount += 1

                    if let accountId = transaction.accountId {
                        accountOutflowTotals[accountId, default: 0] += amount
                        accountExpenseTotals[accountId, default: 0] += amount
                    }

                    if let categoryId = transaction.categoryId {
                        if let primaryCategoryId = primaryCategoryId(for: categoryId) {
                            primaryExpenseCategoryTotals[primaryCategoryId, default: 0] += amount
                        }
                        if let secondaryCategoryId = secondaryCategoryId(for: categoryId) {
                            secondaryExpenseCategoryTotals[secondaryCategoryId, default: 0] += amount
                        }
                    }

                    dailyExpenses[calendar.startOfDay(for: transaction.date), default: 0] += amount
                    add(amount, kind: .expense, transactionDate: transaction.date, to: &trendBuckets)
                case .income:
                    let amount = decimalValue(from: transaction.amountText)
                    income += amount
                    entryCount += 1

                    if let accountId = transaction.accountId {
                        accountInflowTotals[accountId, default: 0] += amount
                        accountIncomeTotals[accountId, default: 0] += amount
                    }

                    if let categoryId = transaction.categoryId {
                        if let primaryCategoryId = primaryCategoryId(for: categoryId) {
                            primaryIncomeCategoryTotals[primaryCategoryId, default: 0] += amount
                        }
                        if let secondaryCategoryId = secondaryCategoryId(for: categoryId) {
                            secondaryIncomeCategoryTotals[secondaryCategoryId, default: 0] += amount
                        }
                    }

                    add(amount, kind: .income, transactionDate: transaction.date, to: &trendBuckets)
                case .transfer:
                    let outAmount = decimalValue(from: transaction.amountText)
                    let inAmount = decimalValue(from: transaction.transferInAmountText ?? transaction.amountText)
                    if let fromAccountId = transaction.fromAccountId {
                        accountOutflowTotals[fromAccountId, default: 0] += outAmount
                    }
                    if let toAccountId = transaction.toAccountId {
                        accountInflowTotals[toAccountId, default: 0] += inAmount
                    }
                    transferCount += 1
                }
            } else if contains(transaction.date, in: previousInterval) {
                switch transaction.kind {
                case .expense:
                    previousExpense += decimalValue(from: transaction.amountText)
                case .income:
                    previousIncome += decimalValue(from: transaction.amountText)
                case .transfer:
                    break
                }
            }
        }

        let balance = income - expense
        let primaryExpenseItems = makeCategoryRankingItems(from: primaryExpenseCategoryTotals)
        let topCategory = primaryExpenseItems.first
        let rankingSections = makeRankingSections(
            accountOutflowTotals: accountOutflowTotals,
            accountExpenseTotals: accountExpenseTotals,
            primaryExpenseCategoryItems: primaryExpenseItems,
            secondaryExpenseCategoryTotals: secondaryExpenseCategoryTotals,
            accountInflowTotals: accountInflowTotals,
            accountIncomeTotals: accountIncomeTotals,
            primaryIncomeCategoryTotals: primaryIncomeCategoryTotals,
            secondaryIncomeCategoryTotals: secondaryIncomeCategoryTotals
        )

        let summaryMetrics = [
            ReportSummaryMetric(
                id: "expense",
                titleKey: "reports.summary.expense.filtered",
                value: Self.currencyText(from: expense),
                caption: changeCaption(current: expense, previous: previousExpense),
                systemImage: "arrow.down.circle.fill",
                color: .accentColor
            ),
            ReportSummaryMetric(
                id: "income",
                titleKey: "reports.summary.income.filtered",
                value: Self.currencyText(from: income),
                caption: changeCaption(current: income, previous: previousIncome),
                systemImage: "arrow.up.circle.fill",
                color: .green
            ),
            ReportSummaryMetric(
                id: "balance",
                titleKey: "reports.summary.balance.filtered",
                value: Self.currencyText(from: balance),
                caption: balanceCaption(for: balance),
                systemImage: "equal.circle.fill",
                color: .blue
            ),
            ReportSummaryMetric(
                id: "entries",
                titleKey: "reports.summary.entries",
                value: String(format: NSLocalizedString("reports.summary.entries.valueFormat", comment: ""), entryCount),
                caption: String(format: NSLocalizedString("reports.summary.entries.captionFormat", comment: ""), transferCount),
                systemImage: "list.bullet.rectangle.portrait.fill",
                color: .orange
            )
        ]
        let elapsedEndDate = minDate(now, Date(timeInterval: -1, since: interval.end))
        let elapsedDayEnd = calendar.date(
            byAdding: .day,
            value: 1,
            to: calendar.startOfDay(for: elapsedEndDate)
        ) ?? interval.end
        let dayCount = max(
            1,
            calendar.dateComponents(
                [.day],
                from: interval.start,
                to: minDate(elapsedDayEnd, interval.end)
            ).day ?? 1
        )
        let activeExpenseDays = dailyExpenses.values.filter { $0 > 0 }.count
        let averageDailyExpense = expense / Decimal(dayCount)
        let averageActiveDayExpense = activeExpenseDays > 0 ? expense / Decimal(activeExpenseDays) : Decimal(0)
        let maxDailyExpense = dailyExpenses.max { lhs, rhs in
            if lhs.value == rhs.value {
                return lhs.key < rhs.key
            }

            return lhs.value < rhs.value
        }
        let paceHighlights = makePaceHighlights(
            periodName: periodName,
            averageDailyExpense: averageDailyExpense,
            averageActiveDayExpense: averageActiveDayExpense,
            activeExpenseDays: activeExpenseDays,
            dayCount: dayCount,
            maxDailyExpense: maxDailyExpense
        )

        return ReportData(
            summaryMetrics: summaryMetrics,
            trendPoints: trendBuckets.map { $0.point },
            rankingSections: rankingSections,
            paceHighlights: paceHighlights,
            insights: makeInsights(
                periodName: periodName,
                expense: expense,
                income: income,
                balance: balance,
                entryCount: entryCount,
                topCategory: topCategory,
                averageDailyExpense: averageDailyExpense,
                maxDailyExpense: maxDailyExpense
            ),
            periodRangeText: periodRangeText(for: interval),
            periodSummaryText: periodSummaryText(
                entryCount: entryCount,
                transferCount: transferCount,
                activeExpenseDays: activeExpenseDays,
                dayCount: dayCount
            )
        )
    }

    private func add(_ amount: Decimal, kind: DraftEntryKind, transactionDate: Date, to buckets: inout [ReportTrendBucket]) {
        guard let index = buckets.firstIndex(where: { contains(transactionDate, in: $0.interval) }) else { return }

        switch kind {
        case .expense:
            buckets[index].expense += doubleValue(from: amount)
        case .income:
            buckets[index].income += doubleValue(from: amount)
        case .transfer:
            break
        }
    }

    private func contains(_ date: Date, in interval: DateInterval) -> Bool {
        date >= interval.start && date < interval.end
    }

    private func makeRankingSections(
        accountOutflowTotals: [String: Decimal],
        accountExpenseTotals: [String: Decimal],
        primaryExpenseCategoryItems: [ReportRankingItem],
        secondaryExpenseCategoryTotals: [String: Decimal],
        accountInflowTotals: [String: Decimal],
        accountIncomeTotals: [String: Decimal],
        primaryIncomeCategoryTotals: [String: Decimal],
        secondaryIncomeCategoryTotals: [String: Decimal]
    ) -> [ReportRankingSection] {
        [
            ReportRankingSection(
                id: "account-outflow",
                titleKey: "reports.rank.accountOutflow.title",
                subtitleKey: "reports.rank.accountOutflow.subtitle",
                emptyTitleKey: "reports.rank.accountOutflow.empty.title",
                emptySubtitleKey: "reports.rank.accountOutflow.empty.subtitle",
                systemImage: "arrow.up.right.circle.fill",
                totalAmount: doubleValue(from: totalAmount(in: accountOutflowTotals)),
                items: makeAccountRankingItems(from: accountOutflowTotals)
            ),
            ReportRankingSection(
                id: "account-expense",
                titleKey: "reports.rank.accountExpense.title",
                subtitleKey: "reports.rank.accountExpense.subtitle",
                emptyTitleKey: "reports.rank.accountExpense.empty.title",
                emptySubtitleKey: "reports.rank.accountExpense.empty.subtitle",
                systemImage: "creditcard.fill",
                totalAmount: doubleValue(from: totalAmount(in: accountExpenseTotals)),
                items: makeAccountRankingItems(from: accountExpenseTotals)
            ),
            ReportRankingSection(
                id: "primary-expense-category",
                titleKey: "reports.rank.primaryExpenseCategory.title",
                subtitleKey: "reports.rank.primaryExpenseCategory.subtitle",
                emptyTitleKey: "reports.rank.primaryExpenseCategory.empty.title",
                emptySubtitleKey: "reports.rank.primaryExpenseCategory.empty.subtitle",
                systemImage: "chart.pie.fill",
                totalAmount: totalAmount(in: primaryExpenseCategoryItems),
                items: primaryExpenseCategoryItems
            ),
            ReportRankingSection(
                id: "secondary-expense-category",
                titleKey: "reports.rank.secondaryExpenseCategory.title",
                subtitleKey: "reports.rank.secondaryExpenseCategory.subtitle",
                emptyTitleKey: "reports.rank.secondaryExpenseCategory.empty.title",
                emptySubtitleKey: "reports.rank.secondaryExpenseCategory.empty.subtitle",
                systemImage: "square.stack.3d.up.fill",
                totalAmount: doubleValue(from: totalAmount(in: secondaryExpenseCategoryTotals)),
                items: makeCategoryRankingItems(from: secondaryExpenseCategoryTotals)
            ),
            ReportRankingSection(
                id: "account-inflow",
                titleKey: "reports.rank.accountInflow.title",
                subtitleKey: "reports.rank.accountInflow.subtitle",
                emptyTitleKey: "reports.rank.accountInflow.empty.title",
                emptySubtitleKey: "reports.rank.accountInflow.empty.subtitle",
                systemImage: "arrow.down.left.circle.fill",
                totalAmount: doubleValue(from: totalAmount(in: accountInflowTotals)),
                items: makeAccountRankingItems(from: accountInflowTotals)
            ),
            ReportRankingSection(
                id: "account-income",
                titleKey: "reports.rank.accountIncome.title",
                subtitleKey: "reports.rank.accountIncome.subtitle",
                emptyTitleKey: "reports.rank.accountIncome.empty.title",
                emptySubtitleKey: "reports.rank.accountIncome.empty.subtitle",
                systemImage: "banknote.fill",
                totalAmount: doubleValue(from: totalAmount(in: accountIncomeTotals)),
                items: makeAccountRankingItems(from: accountIncomeTotals)
            ),
            ReportRankingSection(
                id: "primary-income-category",
                titleKey: "reports.rank.primaryIncomeCategory.title",
                subtitleKey: "reports.rank.primaryIncomeCategory.subtitle",
                emptyTitleKey: "reports.rank.primaryIncomeCategory.empty.title",
                emptySubtitleKey: "reports.rank.primaryIncomeCategory.empty.subtitle",
                systemImage: "chart.pie.fill",
                totalAmount: doubleValue(from: totalAmount(in: primaryIncomeCategoryTotals)),
                items: makeCategoryRankingItems(from: primaryIncomeCategoryTotals)
            ),
            ReportRankingSection(
                id: "secondary-income-category",
                titleKey: "reports.rank.secondaryIncomeCategory.title",
                subtitleKey: "reports.rank.secondaryIncomeCategory.subtitle",
                emptyTitleKey: "reports.rank.secondaryIncomeCategory.empty.title",
                emptySubtitleKey: "reports.rank.secondaryIncomeCategory.empty.subtitle",
                systemImage: "square.stack.3d.up.fill",
                totalAmount: doubleValue(from: totalAmount(in: secondaryIncomeCategoryTotals)),
                items: makeCategoryRankingItems(from: secondaryIncomeCategoryTotals)
            )
        ]
    }

    private func makeAccountRankingItems(from totals: [String: Decimal]) -> [ReportRankingItem] {
        makeRankingItems(from: totals) { accountId, amount in
            let account = draftStore.accounts.first { $0.id == accountId }
            return ReportRankingItem(
                id: accountId,
                title: accountDisplayName(for: accountId),
                amount: doubleValue(from: amount),
                colorHex: normalizedColorHex(account?.colorHex),
                iconName: normalizedIconName(account?.iconName, fallback: "wallet")
            )
        }
    }

    private func makeCategoryRankingItems(from totals: [String: Decimal]) -> [ReportRankingItem] {
        makeRankingItems(from: totals) { categoryId, amount in
            let category = draftStore.categories.first { $0.id == categoryId }
            return ReportRankingItem(
                id: categoryId,
                title: categoryDisplayName(for: categoryId),
                amount: doubleValue(from: amount),
                colorHex: normalizedColorHex(category?.colorHex),
                iconName: normalizedIconName(category?.iconName, fallback: "tag")
            )
        }
    }

    private func makeRankingItems(
        from totals: [String: Decimal],
        item: (String, Decimal) -> ReportRankingItem
    ) -> [ReportRankingItem] {
        totals
            .filter { $0.value > 0 }
            .map { key, value in
                item(key, value)
            }
            .sorted { lhs, rhs in
                if lhs.amount == rhs.amount {
                    return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
                }

                return lhs.amount > rhs.amount
            }
    }

    private func totalAmount(in totals: [String: Decimal]) -> Decimal {
        totals.values.reduce(Decimal(0), +)
    }

    private func totalAmount(in items: [ReportRankingItem]) -> Double {
        items.reduce(0) { partialResult, item in
            partialResult + item.amount
        }
    }

    private func primaryCategoryId(for categoryId: String) -> String? {
        categoryPath(for: categoryId).first?.id ?? categoryId
    }

    private func secondaryCategoryId(for categoryId: String) -> String? {
        let path = categoryPath(for: categoryId)
        guard path.count >= 2 else { return nil }
        return path[1].id
    }

    private func categoryPath(for categoryId: String) -> [DraftCategory] {
        guard let category = draftStore.categories.first(where: { $0.id == categoryId }) else {
            return []
        }

        var path = [category]
        var visitedIds = Set([category.id])
        var currentCategory = category

        while
            let parentId = currentCategory.parentId,
            !visitedIds.contains(parentId),
            let parent = draftStore.categories.first(where: { $0.id == parentId && $0.kind == category.kind })
        {
            path.append(parent)
            visitedIds.insert(parent.id)
            currentCategory = parent
        }

        return path.reversed()
    }

    private func makeInsights(
        periodName: String,
        expense: Decimal,
        income: Decimal,
        balance: Decimal,
        entryCount: Int,
        topCategory: ReportRankingItem?,
        averageDailyExpense: Decimal,
        maxDailyExpense: (key: Date, value: Decimal)?
    ) -> [ReportInsight] {
        var insights: [ReportInsight] = []

        if entryCount == 0, expense == 0, income == 0 {
            return [
                ReportInsight(
                    id: "empty",
                    title: NSLocalizedString("reports.insight.empty.title", comment: ""),
                    subtitle: NSLocalizedString("reports.insight.empty.subtitle", comment: ""),
                    systemImage: "sparkles",
                    color: .secondary
                )
            ]
        }

        if let topCategory {
            insights.append(
                ReportInsight(
                    id: "top-category",
                    title: String(format: NSLocalizedString("reports.insight.topCategory.titleFormat", comment: ""), topCategory.title),
                    subtitle: String(
                        format: NSLocalizedString("reports.insight.topCategory.subtitleFormat", comment: ""),
                        topCategory.title,
                        percentText(part: Decimal(topCategory.amount), total: expense),
                        Self.currencyText(from: Decimal(topCategory.amount))
                    ),
                    systemImage: "chart.bar.xaxis",
                    color: .orange
                )
            )
        }

        insights.append(
            ReportInsight(
                id: "cash-flow",
                title: balance >= 0
                    ? NSLocalizedString("reports.insight.cashFlow.positive.title", comment: "")
                    : NSLocalizedString("reports.insight.cashFlow.negative.title", comment: ""),
                subtitle: String(
                    format: balance >= 0
                        ? NSLocalizedString("reports.insight.cashFlow.positive.subtitleFormat", comment: "")
                        : NSLocalizedString("reports.insight.cashFlow.negative.subtitleFormat", comment: ""),
                    Self.currencyText(from: absDecimal(balance))
                ),
                systemImage: balance >= 0 ? "checkmark.circle.fill" : "exclamationmark.circle.fill",
                color: balance >= 0 ? .green : .red
            )
        )

        if expense > 0 {
            insights.append(
                ReportInsight(
                    id: "spending-pace",
                    title: NSLocalizedString("reports.insight.pace.title", comment: ""),
                    subtitle: String(
                        format: NSLocalizedString("reports.insight.pace.subtitleFormat", comment: ""),
                        periodName,
                        Self.currencyText(from: averageDailyExpense)
                    ),
                    systemImage: "calendar.badge.clock",
                    color: .purple
                )
            )
        }

        if let maxDailyExpense, maxDailyExpense.value > 0 {
            insights.append(
                ReportInsight(
                    id: "peak-day",
                    title: NSLocalizedString("reports.insight.peakDay.title", comment: ""),
                    subtitle: String(
                        format: NSLocalizedString("reports.insight.peakDay.subtitleFormat", comment: ""),
                        Self.mediumDateFormatter.string(from: maxDailyExpense.key),
                        Self.currencyText(from: maxDailyExpense.value)
                    ),
                    systemImage: "flame.fill",
                    color: .red
                )
            )
        }

        insights.append(
            ReportInsight(
                id: "activity",
                title: NSLocalizedString("reports.insight.activity.title", comment: ""),
                subtitle: String(
                    format: NSLocalizedString("reports.insight.activity.subtitleFormat", comment: ""),
                    periodName,
                    entryCount,
                    Self.currencyText(from: income),
                    Self.currencyText(from: expense)
                ),
                systemImage: "list.bullet.clipboard.fill",
                color: .blue
            )
        )

        if insights.isEmpty {
            insights.append(
                ReportInsight(
                    id: "empty",
                    title: NSLocalizedString("reports.insight.empty.title", comment: ""),
                    subtitle: NSLocalizedString("reports.insight.empty.subtitle", comment: ""),
                    systemImage: "sparkles",
                    color: .secondary
                )
            )
        }

        return insights
    }

    private func makePaceHighlights(
        periodName: String,
        averageDailyExpense: Decimal,
        averageActiveDayExpense: Decimal,
        activeExpenseDays: Int,
        dayCount: Int,
        maxDailyExpense: (key: Date, value: Decimal)?
    ) -> [ReportHighlight] {
        guard activeExpenseDays > 0 else { return [] }

        var highlights = [
            ReportHighlight(
                id: "average-daily-expense",
                titleKey: "reports.pace.averageDaily",
                value: Self.currencyText(from: averageDailyExpense),
                caption: String(
                    format: NSLocalizedString("reports.pace.averageDaily.captionFormat", comment: ""),
                    periodName
                ),
                systemImage: "divide.circle.fill",
                color: .accentColor
            ),
            ReportHighlight(
                id: "active-days",
                titleKey: "reports.pace.activeDays",
                value: String(format: NSLocalizedString("reports.pace.activeDays.valueFormat", comment: ""), activeExpenseDays),
                caption: String(format: NSLocalizedString("reports.pace.activeDays.captionFormat", comment: ""), dayCount),
                systemImage: "calendar.circle.fill",
                color: .blue
            ),
            ReportHighlight(
                id: "average-active-day-expense",
                titleKey: "reports.pace.averageActiveDay",
                value: Self.currencyText(from: averageActiveDayExpense),
                caption: NSLocalizedString("reports.pace.averageActiveDay.caption", comment: ""),
                systemImage: "bolt.circle.fill",
                color: .orange
            )
        ]

        if let maxDailyExpense, maxDailyExpense.value > 0 {
            highlights.append(
                ReportHighlight(
                    id: "peak-day",
                    titleKey: "reports.pace.peakDay",
                    value: Self.currencyText(from: maxDailyExpense.value),
                    caption: Self.mediumDateFormatter.string(from: maxDailyExpense.key),
                    systemImage: "flame.circle.fill",
                    color: .red
                )
            )
        }

        return highlights
    }

    private func changeCaption(current: Decimal, previous: Decimal) -> String {
        guard previous > 0 else {
            return current > 0
                ? NSLocalizedString("reports.summary.caption.noPrevious", comment: "")
                : NSLocalizedString("reports.summary.caption.noData", comment: "")
        }

        let change = (current - previous) / previous
        let changeText = Self.percentFormatter.string(from: NSDecimalNumber(decimal: change)) ?? "0%"

        if change > 0 {
            return String(format: NSLocalizedString("reports.summary.caption.increasedFormat", comment: ""), changeText)
        } else if change < 0 {
            return String(format: NSLocalizedString("reports.summary.caption.decreasedFormat", comment: ""), changeText)
        } else {
            return NSLocalizedString("reports.summary.caption.unchanged", comment: "")
        }
    }

    private func balanceCaption(for balance: Decimal) -> String {
        if balance > 0 {
            return NSLocalizedString("reports.summary.balance.caption.positive", comment: "")
        } else if balance < 0 {
            return NSLocalizedString("reports.summary.balance.caption.negative", comment: "")
        } else {
            return NSLocalizedString("reports.summary.balance.caption.zero", comment: "")
        }
    }

    private func categoryDisplayName(for id: String) -> String {
        let name = draftStore.categoryDisplayName(for: id)
        let isArchived = draftStore.categories.first(where: { $0.id == id })?.isArchived ?? false

        guard isArchived else { return name }
        return String(format: NSLocalizedString("draft.item.archivedFormat", comment: ""), name)
    }

    private func accountDisplayName(for id: String) -> String {
        guard let account = draftStore.accounts.first(where: { $0.id == id }) else {
            return NSLocalizedString("draft.item.missing", comment: "")
        }

        guard account.isArchived else { return account.name }
        return String(format: NSLocalizedString("draft.item.archivedFormat", comment: ""), account.name)
    }

    private func normalizedIconName(_ iconName: String?, fallback: String) -> String {
        guard let iconName, !iconName.isEmpty else { return fallback }
        return iconName
    }

    private func normalizedColorHex(_ colorHex: String?) -> String {
        guard let colorHex, !colorHex.isEmpty else { return "#F6C343" }
        return colorHex
    }

    private func periodRangeText(for interval: DateInterval) -> String {
        let formatter = DateIntervalFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none

        let end = Date(timeInterval: -1, since: interval.end)
        return formatter.string(from: interval.start, to: maxDate(interval.start, end))
    }

    private func periodSummaryText(entryCount: Int, transferCount: Int, activeExpenseDays: Int, dayCount: Int) -> String {
        if entryCount == 0, transferCount == 0 {
            return NSLocalizedString("reports.period.summary.empty", comment: "")
        }

        return String(
            format: NSLocalizedString("reports.period.summary.format", comment: ""),
            entryCount,
            transferCount,
            activeExpenseDays,
            dayCount
        )
    }

    private func percentText(part: Decimal, total: Decimal) -> String {
        guard total > 0 else { return Self.percentFormatter.string(from: 0) ?? "0%" }
        return Self.percentFormatter.string(from: NSDecimalNumber(decimal: part / total)) ?? "0%"
    }

    private func decimalValue(from text: String) -> Decimal {
        let normalizedText = DraftAmountFormatter.normalizedAmountText(text, allowNegative: true) ?? "0"
        return Decimal(string: normalizedText, locale: Locale(identifier: "en_US_POSIX")) ?? 0
    }

    private func doubleValue(from decimal: Decimal) -> Double {
        NSDecimalNumber(decimal: decimal).doubleValue
    }

    private func absDecimal(_ decimal: Decimal) -> Decimal {
        decimal < 0 ? -decimal : decimal
    }

    private func minDate(_ lhs: Date, _ rhs: Date) -> Date {
        lhs < rhs ? lhs : rhs
    }

    private func maxDate(_ lhs: Date, _ rhs: Date) -> Date {
        lhs > rhs ? lhs : rhs
    }

    private func makeTrendBuckets(in interval: DateInterval, calendar: Calendar) -> [ReportTrendBucket] {
        let monthCount = calendar.dateComponents([.month], from: interval.start, to: interval.end).month ?? 0
        if monthCount >= 2 {
            return makeMonthBuckets(in: interval, calendar: calendar)
        }

        return makeDayBuckets(in: interval, calendar: calendar, maxBucketCount: 8)
    }

    private func makeDayBuckets(in interval: DateInterval, calendar: Calendar, maxBucketCount: Int) -> [ReportTrendBucket] {
        let dayCount = calendar.dateComponents([.day], from: interval.start, to: interval.end).day ?? 0
        let bucketSize = max(1, Int(ceil(Double(max(dayCount, 1)) / Double(maxBucketCount))))
        var buckets: [ReportTrendBucket] = []
        var start = interval.start

        while start < interval.end {
            let end = minDate(calendar.date(byAdding: .day, value: bucketSize, to: start) ?? interval.end, interval.end)
            let startDay = calendar.component(.day, from: start)
            let endDay = calendar.component(.day, from: calendar.date(byAdding: .day, value: -1, to: end) ?? start)
            let label = startDay == endDay ? "\(startDay)" : "\(startDay)-\(endDay)"
            buckets.append(
                ReportTrendBucket(
                    label: label,
                    interval: DateInterval(start: start, end: end)
                )
            )
            start = end
        }

        return buckets
    }

    private func makeMonthBuckets(in interval: DateInterval, calendar: Calendar) -> [ReportTrendBucket] {
        var buckets: [ReportTrendBucket] = []
        var start = startOfMonth(for: interval.start, calendar: calendar)
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("MMM")

        while start < interval.end {
            let end = minDate(calendar.date(byAdding: .month, value: 1, to: start) ?? interval.end, interval.end)
            buckets.append(
                ReportTrendBucket(
                    label: formatter.string(from: start),
                    interval: DateInterval(start: start, end: end)
                )
            )
            start = end
        }

        return buckets
    }

    private func startOfMonth(for date: Date, calendar: Calendar) -> Date {
        let components = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: components) ?? date
    }

    fileprivate static func currencyText(from decimal: Decimal) -> String {
        DraftAmountFormatter.currencyText(from: NSDecimalNumber(decimal: decimal).stringValue)
    }

    fileprivate static func currencyText(from amount: Double) -> String {
        DraftAmountFormatter.currencyText(from: NSDecimalNumber(value: amount).stringValue)
    }

    private static let compactCurrencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "CNY"
        formatter.currencySymbol = "¥"
        formatter.maximumFractionDigits = 0
        formatter.usesGroupingSeparator = false
        return formatter
    }()

    private static let percentFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.maximumFractionDigits = 0
        return formatter
    }()

    private static let mediumDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("MMMd")
        return formatter
    }()

    private static func localizedChartLabel(_ key: String) -> String {
        NSLocalizedString(key, comment: "")
    }
}

private struct ReportData {
    let summaryMetrics: [ReportSummaryMetric]
    let trendPoints: [ReportTrendPoint]
    let rankingSections: [ReportRankingSection]
    let paceHighlights: [ReportHighlight]
    let insights: [ReportInsight]
    let periodRangeText: String
    let periodSummaryText: String
}

private struct ReportSummaryMetric: Identifiable {
    let id: String
    let titleKey: LocalizedStringKey
    let value: String
    let caption: String
    let systemImage: String
    let color: Color
}

private struct ReportTrendBucket {
    let label: String
    let interval: DateInterval
    var expense: Double = 0
    var income: Double = 0

    var point: ReportTrendPoint {
        ReportTrendPoint(label: label, expense: expense, income: income)
    }
}

private struct ReportTrendPoint: Identifiable {
    let id = UUID()
    let label: String
    let expense: Double
    let income: Double
}

private struct ReportRankingSection: Identifiable {
    let id: String
    let titleKey: LocalizedStringKey
    let subtitleKey: LocalizedStringKey
    let emptyTitleKey: LocalizedStringKey
    let emptySubtitleKey: LocalizedStringKey
    let systemImage: String
    let totalAmount: Double
    let items: [ReportRankingItem]

    var itemCount: Int {
        items.count
    }

    var topItem: ReportRankingItem? {
        items.first
    }

    var topItemShare: Double {
        guard totalAmount > 0, let topItem else { return 0 }
        return topItem.amount / totalAmount
    }
}

private struct ReportRankingItem: Identifiable {
    let id: String
    let title: String
    let amount: Double
    let colorHex: String
    let iconName: String
}

private struct ReportHighlight: Identifiable {
    let id: String
    let titleKey: LocalizedStringKey
    let value: String
    let caption: String
    let systemImage: String
    let color: Color
}

private struct ReportInsight: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let systemImage: String
    let color: Color
}

private struct ReportCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                Color(.secondarySystemGroupedBackground),
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
    }
}

private struct ReportContextBar: View {
    let rangeText: String
    let summaryText: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "calendar")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.tint)
                .frame(width: 30, height: 30)
                .background(Color.accentColor.opacity(0.14), in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(rangeText)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                Text(summaryText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color(.secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
        )
    }
}

private struct ReportMetricCard: View {
    let metric: ReportSummaryMetric

    var body: some View {
        ReportCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: metric.systemImage)
                        .font(.headline)
                        .foregroundStyle(metric.color)

                    Spacer()
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text(metric.value)
                        .font(.title3.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    Text(metric.titleKey)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(metric.caption)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
            }
            .frame(minHeight: 104, alignment: .topLeading)
        }
    }
}

private struct ReportHighlightRow: View {
    let highlight: ReportHighlight

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: highlight.systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(highlight.color)
                .frame(width: 30, height: 30)
                .background(highlight.color.opacity(0.14), in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(highlight.titleKey)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text(highlight.caption)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            Text(highlight.value)
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .multilineTextAlignment(.trailing)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .padding(.vertical, 10)
    }
}

private struct ReportSectionHeader: View {
    let titleKey: LocalizedStringKey
    let subtitleKey: LocalizedStringKey
    let systemImage: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.tint)
                .frame(width: 28, height: 28)
                .background(Color.accentColor.opacity(0.14), in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(titleKey)
                    .font(.headline)

                Text(subtitleKey)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct ChartLegendDot: View {
    let color: Color
    let titleKey: LocalizedStringKey

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)

            Text(titleKey)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct ReportEmptyState: View {
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
        .frame(maxWidth: .infinity, minHeight: 112, alignment: .leading)
    }
}

private struct ReportRankingOptionRow: View {
    let section: ReportRankingSection

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: section.systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.tint)
                .frame(width: 30, height: 30)
                .background(Color.accentColor.opacity(0.14), in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(section.titleKey)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    if section.itemCount > 0 {
                        Text(String(format: NSLocalizedString("reports.breakdown.itemCountFormat", comment: ""), section.itemCount))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Color.secondary.opacity(0.12), in: Capsule())
                    }
                }

                Text(subtitleText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 3) {
                Text(ReportsPage.currencyText(from: section.totalAmount))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }

    private var subtitleText: String {
        guard let topItem = section.topItem else {
            return NSLocalizedString("reports.breakdown.noData", comment: "")
        }

        let shareText = Self.percentFormatter.string(from: section.topItemShare as NSNumber) ?? "0%"
        return String(
            format: NSLocalizedString("reports.breakdown.topItemFormat", comment: ""),
            topItem.title,
            shareText
        )
    }

    private static let percentFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.maximumFractionDigits = 0
        return formatter
    }()
}

private struct ReportRankingDetailPage: View {
    let section: ReportRankingSection

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ReportCard {
                    VStack(alignment: .leading, spacing: 16) {
                        ReportSectionHeader(
                            titleKey: section.titleKey,
                            subtitleKey: section.subtitleKey,
                            systemImage: section.systemImage
                        )

                        if section.items.isEmpty {
                            ReportEmptyState(
                                systemImage: section.systemImage,
                                titleKey: section.emptyTitleKey,
                                subtitleKey: section.emptySubtitleKey
                            )
                        } else {
                            ViewThatFits(in: .horizontal) {
                                HStack(alignment: .center, spacing: 18) {
                                    rankingPieChart
                                    rankingSummary
                                }

                                VStack(alignment: .leading, spacing: 14) {
                                    rankingPieChart
                                        .frame(maxWidth: .infinity, alignment: .center)
                                    rankingSummary
                                }
                            }
                        }
                    }
                }

                if !section.items.isEmpty {
                    ReportCard {
                        VStack(alignment: .leading, spacing: 14) {
                            ReportSectionHeader(
                                titleKey: "reports.breakdown.ranking.title",
                                subtitleKey: "reports.breakdown.ranking.subtitle",
                                systemImage: "list.number"
                            )

                            VStack(spacing: 12) {
                                ForEach(section.items) { item in
                                    ReportRankingRow(item: item, totalAmount: section.totalAmount)
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 18)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(Text(section.titleKey))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var rankingPieChart: some View {
        Chart(section.items) { item in
            SectorMark(
                angle: .value(Self.localizedChartLabel("reports.chart.axis.amount"), item.amount),
                innerRadius: .ratio(0.62),
                angularInset: 1.5
            )
            .foregroundStyle(Color(hex: item.colorHex).gradient)
        }
        .chartLegend(.hidden)
        .frame(width: 148, height: 148)
    }

    private var rankingSummary: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("reports.breakdown.total")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(ReportsPage.currencyText(from: section.totalAmount))
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)
                .monospacedDigit()

            HStack(spacing: 10) {
                ReportBreakdownSummaryBadge(
                    titleKey: "reports.breakdown.itemCount",
                    value: String(section.itemCount),
                    systemImage: "number.circle.fill"
                )

                ReportBreakdownSummaryBadge(
                    titleKey: "reports.breakdown.topShare",
                    value: Self.percentFormatter.string(from: section.topItemShare as NSNumber) ?? "0%",
                    systemImage: "chart.pie.fill"
                )
            }

            if let topItem = section.topItem {
                Text(
                    String(
                        format: NSLocalizedString("reports.breakdown.topItemFormat", comment: ""),
                        topItem.title,
                        Self.percentFormatter.string(from: section.topItemShare as NSNumber) ?? "0%"
                    )
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private static let percentFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.maximumFractionDigits = 0
        return formatter
    }()

    private static func localizedChartLabel(_ key: String) -> String {
        NSLocalizedString(key, comment: "")
    }
}

private struct ReportBreakdownSummaryBadge: View {
    let titleKey: LocalizedStringKey
    let value: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tint)

            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)

                Text(titleKey)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.secondary.opacity(0.10), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct ReportRankingRow: View {
    let item: ReportRankingItem
    let totalAmount: Double

    private var percentage: Double {
        guard totalAmount > 0 else { return 0 }
        return item.amount / totalAmount
    }

    var body: some View {
        HStack(spacing: 12) {
            DraftVisualBadge(iconName: item.iconName, colorHex: item.colorHex, size: 30)

            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Text(item.title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)

                    Spacer()

                    Text(ReportsPage.currencyText(from: item.amount))
                        .font(.subheadline)
                        .monospacedDigit()
                }

                ProgressView(value: percentage)
                    .tint(Color(hex: item.colorHex))
            }

            Text(Self.percentFormatter.string(from: percentage as NSNumber) ?? "")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 42, alignment: .trailing)
        }
    }

    private static let percentFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.maximumFractionDigits = 0
        return formatter
    }()
}

#Preview {
    ReportsPage()
        .environmentObject(DraftBookkeepingStore())
}
