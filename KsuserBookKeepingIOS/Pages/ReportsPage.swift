import Charts
import SwiftUI

struct ReportsPage: View {
    @State private var selectedPeriod = ReportPeriod.month

    private let summaryMetrics = ReportSampleData.summaryMetrics
    private let trendPoints = ReportSampleData.trendPoints
    private let categorySlices = ReportSampleData.categorySlices
    private let insights = ReportSampleData.insights

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    periodPicker
                    summaryGrid
                    trendSection
                    categorySection
                    budgetSection
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
            ForEach(summaryMetrics) { metric in
                ReportMetricCard(metric: metric)
            }
        }
    }

    private var trendSection: some View {
        ReportCard {
            VStack(alignment: .leading, spacing: 16) {
                ReportSectionHeader(
                    titleKey: "reports.trend.title",
                    subtitleKey: "reports.trend.subtitle",
                    systemImage: "chart.xyaxis.line"
                )

                Chart {
                    ForEach(trendPoints) { point in
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

                HStack(alignment: .center, spacing: 18) {
                    Chart(categorySlices) { slice in
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

                        Text(Self.currencyFormatter.string(from: 4820 as NSNumber) ?? "")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.primary)

                        Text("reports.category.topNote")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                VStack(spacing: 12) {
                    ForEach(categorySlices) { slice in
                        CategoryRankRow(slice: slice, totalAmount: 4820)
                    }
                }
            }
        }
    }

    private var budgetSection: some View {
        ReportCard {
            VStack(alignment: .leading, spacing: 14) {
                ReportSectionHeader(
                    titleKey: "reports.budget.title",
                    subtitleKey: "reports.budget.subtitle",
                    systemImage: "target"
                )

                HStack(alignment: .firstTextBaseline) {
                    Text(Self.currencyFormatter.string(from: 4820 as NSNumber) ?? "")
                        .font(.title2.weight(.semibold))

                    Text("reports.budget.used")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text("68%")
                        .font(.headline)
                        .foregroundStyle(Color.accentColor)
                }

                ProgressView(value: 0.68)
                    .tint(Color.accentColor)

                HStack {
                    Text("reports.budget.monthlyLimit")
                    Spacer()
                    Text(Self.currencyFormatter.string(from: 7000 as NSNumber) ?? "")
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
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
                    ForEach(insights) { insight in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: insight.systemImage)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(insight.color)
                                .frame(width: 24, height: 24)
                                .background(insight.color.opacity(0.14), in: Circle())

                            VStack(alignment: .leading, spacing: 4) {
                                Text(insight.titleKey)
                                    .font(.subheadline.weight(.semibold))

                                Text(insight.subtitleKey)
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

    fileprivate static let currencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "CNY"
        formatter.currencySymbol = "¥"
        formatter.maximumFractionDigits = 0
        return formatter
    }()

    private static let compactCurrencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "CNY"
        formatter.currencySymbol = "¥"
        formatter.maximumFractionDigits = 0
        formatter.usesGroupingSeparator = false
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
}

private struct ReportSummaryMetric: Identifiable {
    let id: String
    let titleKey: LocalizedStringKey
    let value: String
    let captionKey: LocalizedStringKey
    let systemImage: String
    let color: Color
}

private struct ReportTrendPoint: Identifiable {
    let id = UUID()
    let label: String
    let expense: Double
    let income: Double
}

private struct ReportCategorySlice: Identifiable {
    let id: String
    let titleKey: LocalizedStringKey
    let amount: Double
    let colorHex: String
    let iconName: String
}

private struct ReportInsight: Identifiable {
    let id: String
    let titleKey: LocalizedStringKey
    let subtitleKey: LocalizedStringKey
    let systemImage: String
    let color: Color
}

private enum ReportSampleData {
    static let summaryMetrics = [
        ReportSummaryMetric(
            id: "expense",
            titleKey: "reports.summary.expense",
            value: "¥4,820",
            captionKey: "reports.summary.expense.caption",
            systemImage: "arrow.down.circle.fill",
            color: .accentColor
        ),
        ReportSummaryMetric(
            id: "income",
            titleKey: "reports.summary.income",
            value: "¥8,600",
            captionKey: "reports.summary.income.caption",
            systemImage: "arrow.up.circle.fill",
            color: .green
        ),
        ReportSummaryMetric(
            id: "balance",
            titleKey: "reports.summary.balance",
            value: "¥3,780",
            captionKey: "reports.summary.balance.caption",
            systemImage: "equal.circle.fill",
            color: .blue
        ),
        ReportSummaryMetric(
            id: "budget",
            titleKey: "reports.summary.budget",
            value: "68%",
            captionKey: "reports.summary.budget.caption",
            systemImage: "chart.bar.fill",
            color: .orange
        )
    ]

    static let trendPoints = [
        ReportTrendPoint(label: "1", expense: 520, income: 960),
        ReportTrendPoint(label: "5", expense: 860, income: 1240),
        ReportTrendPoint(label: "10", expense: 640, income: 980),
        ReportTrendPoint(label: "15", expense: 730, income: 1120),
        ReportTrendPoint(label: "20", expense: 920, income: 1040),
        ReportTrendPoint(label: "25", expense: 610, income: 1260),
        ReportTrendPoint(label: "30", expense: 540, income: 1160)
    ]

    static let categorySlices = [
        ReportCategorySlice(id: "food", titleKey: "reports.category.food", amount: 1680, colorHex: "#F97316", iconName: "burger"),
        ReportCategorySlice(id: "shopping", titleKey: "reports.category.shopping", amount: 1120, colorHex: "#EC4899", iconName: "bag-shopping"),
        ReportCategorySlice(id: "transport", titleKey: "reports.category.transport", amount: 760, colorHex: "#3B82F6", iconName: "bus"),
        ReportCategorySlice(id: "housing", titleKey: "reports.category.housing", amount: 680, colorHex: "#8B5CF6", iconName: "house"),
        ReportCategorySlice(id: "daily", titleKey: "reports.category.daily", amount: 580, colorHex: "#10B981", iconName: "basket-shopping")
    ]

    static let insights = [
        ReportInsight(
            id: "top-category",
            titleKey: "reports.insight.topCategory.title",
            subtitleKey: "reports.insight.topCategory.subtitle",
            systemImage: "fork.knife.circle.fill",
            color: .orange
        ),
        ReportInsight(
            id: "weekly-down",
            titleKey: "reports.insight.weeklyDown.title",
            subtitleKey: "reports.insight.weeklyDown.subtitle",
            systemImage: "arrow.down.right.circle.fill",
            color: .green
        ),
        ReportInsight(
            id: "budget-safe",
            titleKey: "reports.insight.budgetSafe.title",
            subtitleKey: "reports.insight.budgetSafe.subtitle",
            systemImage: "checkmark.shield.fill",
            color: .blue
        )
    ]
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

                    Text(metric.captionKey)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
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
                    Text(slice.titleKey)
                        .font(.subheadline.weight(.semibold))

                    Spacer()

                    Text(ReportsPage.currencyFormatter.string(from: slice.amount as NSNumber) ?? "")
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
}
