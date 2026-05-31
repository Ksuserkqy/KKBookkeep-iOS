import Charts
import SwiftUI

struct ReportsPage: View {
    @EnvironmentObject private var draftStore: DraftBookkeepingStore
    @State private var selectedPeriod = ReportPeriod.month

    private var reportData: ReportData {
        makeReportData(for: selectedPeriod)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    periodPicker
                    summaryGrid
                    trendSection
                    categorySection
                    insightsSection
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 18)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(Text("tab.reports"))
        }
    }

    private var periodPicker: some View {
        Picker("reports.period.title", selection: $selectedPeriod) {
            ForEach(ReportPeriod.allCases) { period in
                Text(period.titleKey).tag(period)
            }
        }
        .pickerStyle(.segmented)
    }

    private var summaryGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
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
                    subtitleKey: selectedPeriod.trendSubtitleKey,
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

    private var categorySection: some View {
        ReportCard {
            VStack(alignment: .leading, spacing: 16) {
                ReportSectionHeader(
                    titleKey: "reports.category.title",
                    subtitleKey: "reports.category.subtitle",
                    systemImage: "chart.pie.fill"
                )

                if reportData.categorySlices.isEmpty {
                    ReportEmptyState(
                        systemImage: "chart.pie",
                        titleKey: "reports.empty.category.title",
                        subtitleKey: "reports.empty.category.subtitle"
                    )
                } else {
                    HStack(alignment: .center, spacing: 18) {
                        Chart(reportData.categorySlices) { slice in
                            SectorMark(
                                angle: .value(Self.localizedChartLabel("reports.chart.axis.amount"), slice.amount),
                                innerRadius: .ratio(0.62),
                                angularInset: 1.5
                            )
                            .foregroundStyle(Color(hex: slice.colorHex).gradient)
                        }
                        .chartLegend(.hidden)
                        .frame(width: 132, height: 132)

                        VStack(alignment: .leading, spacing: 10) {
                            Text("reports.category.totalExpense")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Text(Self.currencyText(from: reportData.totalExpense))
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(.primary)

                            Text(reportData.topCategoryNote)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    VStack(spacing: 12) {
                        ForEach(reportData.categorySlices) { slice in
                            CategoryRankRow(slice: slice, totalAmount: reportData.totalExpense)
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

    private func makeReportData(for period: ReportPeriod) -> ReportData {
        let calendar = Calendar.current
        let now = Date()
        let interval = period.dateInterval(containing: now, calendar: calendar)
        let previousInterval = period.previousDateInterval(before: interval, calendar: calendar)
        var income = Decimal(0)
        var expense = Decimal(0)
        var previousExpense = Decimal(0)
        var previousIncome = Decimal(0)
        var categoryTotals: [String: Decimal] = [:]
        var entryCount = 0
        var transferCount = 0
        var trendBuckets = period.makeTrendBuckets(in: interval, calendar: calendar)

        for transaction in draftStore.transactions {
            if interval.contains(transaction.date) {
                switch transaction.kind {
                case .expense:
                    let amount = decimalValue(from: transaction.amountText)
                    expense += amount
                    entryCount += 1

                    if let categoryId = transaction.categoryId {
                        categoryTotals[categoryId, default: 0] += amount
                    }

                    add(amount, kind: .expense, transactionDate: transaction.date, to: &trendBuckets)
                case .income:
                    let amount = decimalValue(from: transaction.amountText)
                    income += amount
                    entryCount += 1
                    add(amount, kind: .income, transactionDate: transaction.date, to: &trendBuckets)
                case .transfer:
                    transferCount += 1
                }
            } else if previousInterval.contains(transaction.date) {
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
        let categorySlices = categoryTotals
            .sorted { lhs, rhs in
                if lhs.value == rhs.value {
                    return categoryDisplayName(for: lhs.key) < categoryDisplayName(for: rhs.key)
                }

                return lhs.value > rhs.value
            }
            .prefix(5)
            .map { categoryId, amount in
                let category = draftStore.categories.first { $0.id == categoryId }
                return ReportCategorySlice(
                    id: categoryId,
                    title: categoryDisplayName(for: categoryId),
                    amount: doubleValue(from: amount),
                    colorHex: normalizedColorHex(category?.colorHex),
                    iconName: normalizedIconName(category?.iconName)
                )
            }

        let topCategory = categorySlices.first
        let topCategoryNote = topCategory.map {
            String(
                format: NSLocalizedString("reports.category.topNoteFormat", comment: ""),
                $0.title,
                percentText(part: Decimal($0.amount), total: expense)
            )
        } ?? NSLocalizedString("reports.category.noTopNote", comment: "")

        let summaryMetrics = [
            ReportSummaryMetric(
                id: "expense",
                titleKey: period.expenseTitleKey,
                value: Self.currencyText(from: expense),
                caption: changeCaption(current: expense, previous: previousExpense),
                systemImage: "arrow.down.circle.fill",
                color: .accentColor
            ),
            ReportSummaryMetric(
                id: "income",
                titleKey: period.incomeTitleKey,
                value: Self.currencyText(from: income),
                caption: changeCaption(current: income, previous: previousIncome),
                systemImage: "arrow.up.circle.fill",
                color: .green
            ),
            ReportSummaryMetric(
                id: "balance",
                titleKey: period.balanceTitleKey,
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

        return ReportData(
            summaryMetrics: summaryMetrics,
            trendPoints: trendBuckets.map { $0.point },
            categorySlices: Array(categorySlices),
            insights: makeInsights(
                period: period,
                expense: expense,
                income: income,
                balance: balance,
                entryCount: entryCount,
                topCategory: topCategory
            ),
            totalExpense: doubleValue(from: expense),
            topCategoryNote: topCategoryNote
        )
    }

    private func add(_ amount: Decimal, kind: DraftEntryKind, transactionDate: Date, to buckets: inout [ReportTrendBucket]) {
        guard let index = buckets.firstIndex(where: { $0.interval.contains(transactionDate) }) else { return }

        switch kind {
        case .expense:
            buckets[index].expense += doubleValue(from: amount)
        case .income:
            buckets[index].income += doubleValue(from: amount)
        case .transfer:
            break
        }
    }

    private func makeInsights(
        period: ReportPeriod,
        expense: Decimal,
        income: Decimal,
        balance: Decimal,
        entryCount: Int,
        topCategory: ReportCategorySlice?
    ) -> [ReportInsight] {
        var insights: [ReportInsight] = []

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

        insights.append(
            ReportInsight(
                id: "activity",
                title: NSLocalizedString("reports.insight.activity.title", comment: ""),
                subtitle: String(
                    format: NSLocalizedString("reports.insight.activity.subtitleFormat", comment: ""),
                    period.localizedName,
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

    private func normalizedIconName(_ iconName: String?) -> String {
        guard let iconName, !iconName.isEmpty else { return "tag" }
        return iconName
    }

    private func normalizedColorHex(_ colorHex: String?) -> String {
        guard let colorHex, !colorHex.isEmpty else { return "#F6C343" }
        return colorHex
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

    private static func localizedChartLabel(_ key: String) -> String {
        NSLocalizedString(key, comment: "")
    }
}

private enum ReportPeriod: String, CaseIterable, Identifiable {
    case month
    case quarter
    case year

    var id: String { rawValue }

    var titleKey: LocalizedStringKey {
        switch self {
        case .month:
            return "reports.period.month"
        case .quarter:
            return "reports.period.quarter"
        case .year:
            return "reports.period.year"
        }
    }

    var localizedName: String {
        NSLocalizedString(titleKeyString, comment: "")
    }

    var titleKeyString: String {
        switch self {
        case .month:
            return "reports.period.month"
        case .quarter:
            return "reports.period.quarter"
        case .year:
            return "reports.period.year"
        }
    }

    var expenseTitleKey: LocalizedStringKey {
        switch self {
        case .month:
            return "reports.summary.expense.month"
        case .quarter:
            return "reports.summary.expense.quarter"
        case .year:
            return "reports.summary.expense.year"
        }
    }

    var incomeTitleKey: LocalizedStringKey {
        switch self {
        case .month:
            return "reports.summary.income.month"
        case .quarter:
            return "reports.summary.income.quarter"
        case .year:
            return "reports.summary.income.year"
        }
    }

    var balanceTitleKey: LocalizedStringKey {
        switch self {
        case .month:
            return "reports.summary.balance.month"
        case .quarter:
            return "reports.summary.balance.quarter"
        case .year:
            return "reports.summary.balance.year"
        }
    }

    var trendSubtitleKey: LocalizedStringKey {
        switch self {
        case .month:
            return "reports.trend.subtitle.month"
        case .quarter:
            return "reports.trend.subtitle.quarter"
        case .year:
            return "reports.trend.subtitle.year"
        }
    }

    func dateInterval(containing date: Date, calendar: Calendar) -> DateInterval {
        switch self {
        case .month:
            return calendar.dateInterval(of: .month, for: date) ?? fallbackInterval(endingAt: date, days: 30, calendar: calendar)
        case .quarter:
            let month = calendar.component(.month, from: date)
            let quarterStartMonth = ((month - 1) / 3) * 3 + 1
            var components = calendar.dateComponents([.year], from: date)
            components.month = quarterStartMonth
            components.day = 1
            let start = calendar.date(from: components) ?? date
            let end = calendar.date(byAdding: .month, value: 3, to: start) ?? date
            return DateInterval(start: start, end: end)
        case .year:
            return calendar.dateInterval(of: .year, for: date) ?? fallbackInterval(endingAt: date, days: 365, calendar: calendar)
        }
    }

    func previousDateInterval(before interval: DateInterval, calendar: Calendar) -> DateInterval {
        let component: Calendar.Component
        let value: Int

        switch self {
        case .month:
            component = .month
            value = -1
        case .quarter:
            component = .month
            value = -3
        case .year:
            component = .year
            value = -1
        }

        let start = calendar.date(byAdding: component, value: value, to: interval.start) ?? interval.start
        let end = calendar.date(byAdding: component, value: value, to: interval.end) ?? interval.start
        return DateInterval(start: start, end: end)
    }

    func makeTrendBuckets(in interval: DateInterval, calendar: Calendar) -> [ReportTrendBucket] {
        switch self {
        case .month:
            return makeDayBuckets(in: interval, calendar: calendar, maxBucketCount: 8)
        case .quarter:
            return makeMonthBuckets(in: interval, calendar: calendar)
        case .year:
            return makeMonthBuckets(in: interval, calendar: calendar)
        }
    }

    private func makeDayBuckets(in interval: DateInterval, calendar: Calendar, maxBucketCount: Int) -> [ReportTrendBucket] {
        let dayCount = calendar.dateComponents([.day], from: interval.start, to: interval.end).day ?? 0
        let bucketSize = max(1, Int(ceil(Double(dayCount) / Double(maxBucketCount))))
        var buckets: [ReportTrendBucket] = []
        var start = interval.start

        while start < interval.end {
            let end = minDate(calendar.date(byAdding: .day, value: bucketSize, to: start) ?? interval.end, interval.end)
            let startDay = calendar.component(.day, from: start)
            let endDay = calendar.component(.day, from: calendar.date(byAdding: .day, value: -1, to: end) ?? start)
            let label = startDay == endDay ? "\(startDay)" : "\(startDay)-\(endDay)"
            buckets.append(ReportTrendBucket(label: label, interval: DateInterval(start: start, end: end)))
            start = end
        }

        return buckets
    }

    private func makeMonthBuckets(in interval: DateInterval, calendar: Calendar) -> [ReportTrendBucket] {
        var buckets: [ReportTrendBucket] = []
        var start = interval.start
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("MMM")

        while start < interval.end {
            let end = minDate(calendar.date(byAdding: .month, value: 1, to: start) ?? interval.end, interval.end)
            buckets.append(ReportTrendBucket(label: formatter.string(from: start), interval: DateInterval(start: start, end: end)))
            start = end
        }

        return buckets
    }

    private func fallbackInterval(endingAt date: Date, days: Int, calendar: Calendar) -> DateInterval {
        let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: date)) ?? date
        let start = calendar.date(byAdding: .day, value: -days, to: end) ?? date
        return DateInterval(start: start, end: end)
    }

    private func minDate(_ lhs: Date, _ rhs: Date) -> Date {
        lhs < rhs ? lhs : rhs
    }
}

private struct ReportData {
    let summaryMetrics: [ReportSummaryMetric]
    let trendPoints: [ReportTrendPoint]
    let categorySlices: [ReportCategorySlice]
    let insights: [ReportInsight]
    let totalExpense: Double
    let topCategoryNote: String
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

private struct ReportCategorySlice: Identifiable {
    let id: String
    let title: String
    let amount: Double
    let colorHex: String
    let iconName: String
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
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
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

private struct CategoryRankRow: View {
    let slice: ReportCategorySlice
    let totalAmount: Double

    private var percentage: Double {
        guard totalAmount > 0 else { return 0 }
        return slice.amount / totalAmount
    }

    var body: some View {
        HStack(spacing: 12) {
            DraftVisualBadge(iconName: slice.iconName, colorHex: slice.colorHex, size: 30)

            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Text(slice.title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)

                    Spacer()

                    Text(ReportsPage.currencyText(from: slice.amount))
                        .font(.subheadline)
                        .monospacedDigit()
                }

                ProgressView(value: percentage)
                    .tint(Color(hex: slice.colorHex))
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
