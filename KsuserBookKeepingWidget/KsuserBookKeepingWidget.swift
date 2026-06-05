import SwiftUI
import WidgetKit
#if canImport(ActivityKit)
import ActivityKit
#endif

struct LedgerWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetLedgerSnapshot
}

struct LedgerWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> LedgerWidgetEntry {
        LedgerWidgetEntry(date: Date(), snapshot: .empty)
    }

    func getSnapshot(in context: Context, completion: @escaping (LedgerWidgetEntry) -> Void) {
        completion(LedgerWidgetEntry(date: Date(), snapshot: WidgetSnapshotStore.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<LedgerWidgetEntry>) -> Void) {
        let now = Date()
        let entry = LedgerWidgetEntry(date: now, snapshot: WidgetSnapshotStore.load())
        let nextRefresh = Calendar.current.date(byAdding: .minute, value: 15, to: now) ?? now.addingTimeInterval(900)
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }
}

@main
struct KsuserBookKeepingWidgetBundle: WidgetBundle {
    var body: some Widget {
        QuickRecordWidget()
        LedgerOverviewWidget()
        LedgerReportWidget()
        RecentTransactionLiveActivityWidget()
        BudgetLiveActivityWidget()
    }
}

struct QuickRecordWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "QuickRecordWidget", provider: LedgerWidgetProvider()) { entry in
            QuickRecordWidgetView(entry: entry)
        }
        .configurationDisplayName("widget.quickRecord.title")
        .description("widget.quickRecord.description")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryCircular, .accessoryRectangular])
    }
}

struct LedgerOverviewWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "LedgerOverviewWidget", provider: LedgerWidgetProvider()) { entry in
            LedgerOverviewWidgetView(entry: entry)
        }
        .configurationDisplayName("widget.overview.title")
        .description("widget.overview.description")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}

struct LedgerReportWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "LedgerReportWidget", provider: LedgerWidgetProvider()) { entry in
            LedgerReportWidgetView(entry: entry)
        }
        .configurationDisplayName("widget.report.title")
        .description("widget.report.description")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

#if canImport(ActivityKit)
struct RecentTransactionLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RecentTransactionActivityAttributes.self) { context in
            RecentTransactionLockScreenView(state: context.state)
                .activityBackgroundTint(Color(.systemBackground))
                .activitySystemActionForegroundColor(Color(hex: context.state.accountColorHex))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.center) {
                    LiveActivityExpandedHeader(state: context.state)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    LiveActivityExpandedDetails(state: context.state)
                }
            } compactLeading: {
                LiveActivityAccountBadge(state: context.state, size: 22)
            } compactTrailing: {
                Text(context.state.amountText)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(context.state.amountColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
            } minimal: {
                WidgetFontAwesomeIcon(name: context.state.accountIconName, size: 12)
                    .foregroundStyle(Color(hex: context.state.accountColorHex))
            }
            .widgetURL(WidgetDeepLink.transactions)
            .keylineTint(Color(hex: context.state.accountColorHex))
        }
    }
}

struct BudgetLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: BudgetActivityAttributes.self) { context in
            BudgetLockScreenView(state: context.state)
                .activityBackgroundTint(Color(.systemBackground))
                .activitySystemActionForegroundColor(context.state.tintColor)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.center) {
                    BudgetExpandedHeader(state: context.state)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    BudgetExpandedDetails(state: context.state)
                }
            } compactLeading: {
                Image(systemName: "chart.pie.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(context.state.tintColor)
            } compactTrailing: {
                Text(context.state.percentText)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(context.state.tintColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            } minimal: {
                Image(systemName: "chart.pie.fill")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(context.state.tintColor)
            }
            .widgetURL(WidgetDeepLink.reports)
            .keylineTint(context.state.tintColor)
        }
    }
}
#endif

private struct QuickRecordWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: LedgerWidgetEntry

    var body: some View {
        Group {
            switch family {
            case .accessoryCircular:
                Link(destination: WidgetDeepLink.record(kind: .expense)) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3.weight(.bold))
                }
            case .accessoryRectangular:
                Link(destination: WidgetDeepLink.record(kind: .expense)) {
                    Label("widget.quickRecord.expense", systemImage: "minus.circle.fill")
                        .font(.headline)
                }
            case .systemMedium:
                MediumQuickRecord(snapshot: entry.snapshot)
            case .systemLarge:
                LargeQuickRecord(snapshot: entry.snapshot)
            default:
                SmallQuickRecord()
            }
        }
        .widgetContainerBackground()
    }
}

private struct SmallQuickRecord: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            WidgetHeader(titleKey: "widget.quickRecord.title", systemImage: "plus.circle.fill")

            VStack(spacing: 8) {
                QuickRecordLink(kind: .expense, titleKey: "widget.quickRecord.expense", systemImage: "minus.circle.fill", color: .red)
                QuickRecordLink(kind: .income, titleKey: "widget.quickRecord.income", systemImage: "plus.circle.fill", color: .green)
                QuickRecordLink(kind: .transfer, titleKey: "widget.quickRecord.transfer", systemImage: "arrow.left.arrow.right.circle.fill", color: .blue)
            }
        }
    }
}

private struct MediumQuickRecord: View {
    let snapshot: WidgetLedgerSnapshot

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                WidgetHeader(titleKey: "widget.quickRecord.title", systemImage: "plus.circle.fill")

                CompactMetric(titleKey: "dashboard.todayExpense", value: snapshot.todayExpenseText, color: .red)
                CompactMetric(titleKey: "dashboard.monthBalance", value: snapshot.monthBalanceText, color: .accentColor)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 8) {
                QuickRecordTile(kind: .expense, titleKey: "widget.quickRecord.expense", systemImage: "minus.circle.fill", color: .red)
                QuickRecordTile(kind: .income, titleKey: "widget.quickRecord.income", systemImage: "plus.circle.fill", color: .green)
                QuickRecordTile(kind: .transfer, titleKey: "widget.quickRecord.transfer", systemImage: "arrow.left.arrow.right.circle.fill", color: .blue)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

private struct LargeQuickRecord: View {
    let snapshot: WidgetLedgerSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            WidgetHeader(titleKey: "widget.quickRecord.title", systemImage: "plus.circle.fill")

            HStack(alignment: .firstTextBaseline, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("dashboard.totalBalance")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(snapshot.totalBalanceText)
                        .font(.system(.title2, design: .rounded).weight(.bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 4) {
                    Text("dashboard.todayExpense")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(snapshot.todayExpenseText)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.red)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                QuickRecordTile(kind: .expense, titleKey: "widget.quickRecord.expense", systemImage: "minus.circle.fill", color: .red)
                QuickRecordTile(kind: .income, titleKey: "widget.quickRecord.income", systemImage: "plus.circle.fill", color: .green)
                QuickRecordTile(kind: .transfer, titleKey: "widget.quickRecord.transfer", systemImage: "arrow.left.arrow.right.circle.fill", color: .blue)
            }

            HStack(spacing: 8) {
                MetricChip(titleKey: "dashboard.monthIncome", value: snapshot.monthIncomeText, color: .green)
                MetricChip(titleKey: "dashboard.monthExpense", value: snapshot.monthExpenseText, color: .red)
                MetricChip(titleKey: "dashboard.monthBalance", value: snapshot.monthBalanceText, color: .accentColor)
            }
        }
    }
}

private struct QuickRecordTile: View {
    let kind: WidgetRecordKind
    let titleKey: LocalizedStringKey
    let systemImage: String
    let color: Color

    var body: some View {
        Link(destination: WidgetDeepLink.record(kind: kind)) {
            VStack(spacing: 7) {
                Image(systemName: systemImage)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(color)
                    .frame(width: 34, height: 34)
                    .background(color.opacity(0.14), in: Circle())

                Text(titleKey)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        }
    }
}

private struct LedgerOverviewWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: LedgerWidgetEntry

    var body: some View {
        Link(destination: WidgetDeepLink.dashboard) {
            Group {
                switch family {
                case .accessoryRectangular:
                    AccessoryOverview(snapshot: entry.snapshot)
                case .systemMedium:
                    MediumOverview(snapshot: entry.snapshot)
                default:
                    SmallOverview(snapshot: entry.snapshot)
                }
            }
        }
        .widgetContainerBackground()
    }
}

private struct LedgerReportWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: LedgerWidgetEntry

    var body: some View {
        Link(destination: WidgetDeepLink.reports) {
            Group {
                switch family {
                case .systemMedium:
                    MediumReportPreview(snapshot: entry.snapshot)
                default:
                    LargeReportPreview(snapshot: entry.snapshot)
                }
            }
        }
        .widgetContainerBackground()
    }
}

private struct MediumReportPreview: View {
    let snapshot: WidgetLedgerSnapshot

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 10) {
                WidgetHeader(titleKey: "widget.report.title", systemImage: "chart.pie.fill")

                VStack(alignment: .leading, spacing: 5) {
                    Text("dashboard.monthExpense")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(snapshot.monthExpenseText)
                        .font(.system(.title3, design: .rounded).weight(.bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }

                HStack(spacing: 8) {
                    CompactMetric(titleKey: "dashboard.monthIncome", value: snapshot.monthIncomeText, color: .green)
                    CompactMetric(titleKey: "dashboard.monthBalance", value: snapshot.monthBalanceText, color: .accentColor)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 8) {
                MiniTrendChart(points: snapshot.dailyPoints)
                    .frame(height: 72)

                CompactReportFooter(snapshot: snapshot)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

private struct LargeReportPreview: View {
    let snapshot: WidgetLedgerSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            WidgetHeader(titleKey: "widget.report.title", systemImage: "chart.pie.fill")

            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("dashboard.monthExpense")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(snapshot.monthExpenseText)
                        .font(.system(.title3, design: .rounded).weight(.bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 3) {
                    Text("dashboard.monthIncome")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(snapshot.monthIncomeText)
                        .font(.system(.title3, design: .rounded).weight(.bold))
                        .foregroundStyle(.green)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }
            }

            MiniTrendChart(points: snapshot.dailyPoints)
                .frame(height: 92)

            LargeReportDetails(snapshot: snapshot)
        }
    }
}

private struct CompactMetric: View {
    let titleKey: LocalizedStringKey
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(titleKey)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct CompactReportFooter: View {
    let snapshot: WidgetLedgerSnapshot

    var body: some View {
        HStack(spacing: 6) {
            if let topName = snapshot.topExpenseCategoryName {
                VStack(alignment: .leading, spacing: 1) {
                    Text("dashboard.topExpenseCategory")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Text(topName)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                }
            } else {
                Text("widget.report.emptyTopCategory")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)

            Text(String(format: NSLocalizedString("dashboard.monthTransactions.valueFormat", comment: ""), snapshot.monthTransactionCount))
                .font(.caption2.weight(.semibold))
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .background(Color.accentColor.opacity(0.16), in: Capsule())
        }
    }
}

private struct SmallOverview: View {
    let snapshot: WidgetLedgerSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            WidgetHeader(titleKey: "widget.overview.title", systemImage: "wallet.pass.fill")

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 4) {
                Text("dashboard.totalBalance")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(snapshot.totalBalanceText)
                    .font(.system(.title2, design: .rounded).weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.62)
            }

            HStack {
                MetricChip(titleKey: "dashboard.monthExpense", value: snapshot.monthExpenseText, color: .red)
                Spacer(minLength: 4)
            }
        }
    }
}

private struct MediumOverview: View {
    let snapshot: WidgetLedgerSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            WidgetHeader(titleKey: "widget.overview.title", systemImage: "wallet.pass.fill")

            HStack(alignment: .firstTextBaseline, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("dashboard.totalBalance")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(snapshot.totalBalanceText)
                        .font(.system(.title2, design: .rounded).weight(.bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }

                Spacer(minLength: 0)

                VStack(alignment: .trailing, spacing: 4) {
                    Text("dashboard.todayExpense")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(snapshot.todayExpenseText)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.red)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }
            }

            HStack(spacing: 8) {
                MetricChip(titleKey: "dashboard.monthIncome", value: snapshot.monthIncomeText, color: .green)
                MetricChip(titleKey: "dashboard.monthExpense", value: snapshot.monthExpenseText, color: .red)
                MetricChip(titleKey: "dashboard.monthBalance", value: snapshot.monthBalanceText, color: .accentColor)
            }
        }
    }
}

private struct AccessoryOverview: View {
    let snapshot: WidgetLedgerSnapshot

    var body: some View {
        VStack(alignment: .leading) {
            Text("dashboard.totalBalance")
                .font(.caption)
            Text(snapshot.totalBalanceText)
                .font(.headline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
    }
}

private struct LargeReportDetails: View {
    let snapshot: WidgetLedgerSnapshot

    var body: some View {
        VStack(spacing: 9) {
            ReportFooter(snapshot: snapshot)

            if snapshot.recentTransactions.isEmpty {
                Text("widget.report.emptyRecent")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ForEach(snapshot.recentTransactions) { transaction in
                    HStack(spacing: 8) {
                        Image(systemName: transaction.kind.symbolName)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(transaction.kind.tintColor)
                            .frame(width: 22, height: 22)
                            .background(transaction.kind.tintColor.opacity(0.14), in: Circle())

                        VStack(alignment: .leading, spacing: 1) {
                            Text(transaction.title)
                                .font(.caption.weight(.medium))
                                .lineLimit(1)
                            Text(transaction.dateText)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        Spacer(minLength: 8)

                        Text(transaction.amountText)
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.74)
                    }
                }
            }
        }
    }
}

private struct ReportFooter: View {
    let snapshot: WidgetLedgerSnapshot

    var body: some View {
        HStack(spacing: 8) {
            if let topName = snapshot.topExpenseCategoryName, let topAmount = snapshot.topExpenseCategoryAmountText {
                VStack(alignment: .leading, spacing: 2) {
                    Text("dashboard.topExpenseCategory")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(topName)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                    Text(topAmount)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            } else {
                Text("widget.report.emptyTopCategory")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Spacer(minLength: 0)

            Text(String(format: NSLocalizedString("dashboard.monthTransactions.valueFormat", comment: ""), snapshot.monthTransactionCount))
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Color.accentColor.opacity(0.16), in: Capsule())
        }
    }
}

private struct MiniTrendChart: View {
    let points: [WidgetDailyPoint]

    private var visiblePoints: [WidgetDailyPoint] {
        points.filter { $0.income > 0 || $0.expense > 0 }
    }

    private var maxValue: Double {
        max(visiblePoints.map { max($0.income, $0.expense) }.max() ?? 0, 1)
    }

    var body: some View {
        GeometryReader { proxy in
            let bars = Array(visiblePoints.suffix(12))
            let width = max(proxy.size.width, 1)
            let height = max(proxy.size.height, 1)
            let gap: CGFloat = 3
            let barWidth = max((width - CGFloat(max(bars.count - 1, 0)) * gap) / CGFloat(max(bars.count, 1)), 4)

            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.secondary.opacity(0.08))

                if bars.isEmpty {
                    Text("reports.empty.trend.title")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ForEach(Array(bars.enumerated()), id: \.element.id) { index, point in
                        let expenseHeight = max(CGFloat(point.expense / maxValue) * (height - 12), 3)
                        let incomeHeight = max(CGFloat(point.income / maxValue) * (height - 12), point.income > 0 ? 3 : 0)
                        let x = CGFloat(index) * (barWidth + gap) + 6

                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.red.opacity(0.72))
                            .frame(width: barWidth, height: expenseHeight)
                            .offset(x: x, y: -6)

                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.green.opacity(0.7))
                            .frame(width: max(barWidth * 0.42, 2), height: incomeHeight)
                            .offset(x: x + barWidth * 0.54, y: -6)
                    }
                }
            }
        }
    }
}

private struct QuickRecordLink: View {
    let kind: WidgetRecordKind
    let titleKey: LocalizedStringKey
    let systemImage: String
    let color: Color

    var body: some View {
        Link(destination: WidgetDeepLink.record(kind: kind)) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(color)
                    .frame(width: 22, height: 22)
                    .background(color.opacity(0.14), in: Circle())

                Text(titleKey)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        }
    }
}

#if canImport(ActivityKit)
private struct RecentTransactionLockScreenView: View {
    let state: RecentTransactionActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 12) {
            LiveActivityAccountBadge(state: state, size: 42)

            VStack(alignment: .leading, spacing: 4) {
                Text("liveActivity.title")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(state.title)
                    .font(.headline.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Text(state.accountName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            LiveActivityAmountBlock(state: state, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

private struct LiveActivityExpandedHeader: View {
    let state: RecentTransactionActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 10) {
            LiveActivityAccountBadge(state: state, size: 42)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    LiveActivityAppIcon(size: 15)

                    Text("liveActivity.title")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Text(state.title)
                    .font(.headline.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .layoutPriority(1)

            LiveActivityAmountBlock(state: state, alignment: .trailing)
                .frame(minWidth: 88, alignment: .trailing)
        }
        .padding(.horizontal, 2)
    }
}

private struct LiveActivityExpandedDetails: View {
    let state: RecentTransactionActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Divider()
                .overlay(Color.white.opacity(0.2))

            HStack(spacing: 8) {
                LiveActivityDetailPill(
                    systemImage: "wallet.pass.fill",
                    text: state.accountName
                )

                if let counterpartyAccountName = state.counterpartyAccountName {
                    LiveActivityDetailPill(
                        systemImage: "arrow.right",
                        text: counterpartyAccountName
                    )
                } else if let categoryName = state.categoryName {
                    LiveActivityDetailPill(
                        systemImage: "tag.fill",
                        text: categoryName
                    )
                }
            }

            if !state.note.isEmpty {
                Text(state.note)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 2)
    }
}

private struct LiveActivityDetailPill: View {
    let systemImage: String
    let text: String

    var body: some View {
        Label {
            Text(text)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        } icon: {
            Image(systemName: systemImage)
                .font(.caption2.weight(.semibold))
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.12), in: Capsule())
    }
}

private struct LiveActivityAccountBadge: View {
    let state: RecentTransactionActivityAttributes.ContentState
    let size: CGFloat

    var body: some View {
        WidgetFontAwesomeIcon(name: state.accountIconName, size: max(size * 0.42, 11))
            .foregroundStyle(Color(hex: state.accountColorHex))
            .frame(width: size, height: size)
            .background(Color(hex: state.accountColorHex).opacity(0.18), in: Circle())
            .accessibilityLabel(Text(state.accountName))
    }
}

private struct LiveActivityAmountBlock: View {
    let state: RecentTransactionActivityAttributes.ContentState
    let alignment: HorizontalAlignment

    var body: some View {
        VStack(alignment: alignment, spacing: 3) {
            Text(state.kind.liveActivityTitleKey)
                .font(.caption2)
                .foregroundStyle(.secondary)

            Text(state.amountText)
                .font(.title3.weight(.bold))
                .foregroundStyle(state.amountColor)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
        .fixedSize(horizontal: true, vertical: false)
    }
}

private struct BudgetLockScreenView: View {
    let state: BudgetActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 12) {
            BudgetRing(state: state, size: 46)

            VStack(alignment: .leading, spacing: 4) {
                Text("liveActivity.budget.title")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(state.title)
                    .font(.headline.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Text(state.targetName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            BudgetAmountBlock(state: state, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

private struct BudgetExpandedHeader: View {
    let state: BudgetActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 10) {
            BudgetRing(state: state, size: 44)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    LiveActivityAppIcon(size: 15)

                    Text("liveActivity.budget.title")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Text(state.title)
                    .font(.headline.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .layoutPriority(1)

            BudgetAmountBlock(state: state, alignment: .trailing)
                .frame(minWidth: 88, alignment: .trailing)
        }
        .padding(.horizontal, 2)
    }
}

private struct BudgetExpandedDetails: View {
    let state: BudgetActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()
                .overlay(Color.white.opacity(0.2))

            ProgressView(value: min(max(state.percentUsed, 0), 1))
                .tint(state.tintColor)

            HStack(spacing: 8) {
                LiveActivityDetailPill(
                    systemImage: "minus.circle.fill",
                    text: state.transactionAmountText
                )

                LiveActivityDetailPill(
                    systemImage: "chart.pie.fill",
                    text: String(format: NSLocalizedString("liveActivity.budget.spentFormat", comment: ""), state.spentText, state.limitText)
                )
            }

            Text(state.transactionTitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 2)
    }
}

private struct BudgetRing: View {
    let state: BudgetActivityAttributes.ContentState
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .stroke(state.tintColor.opacity(0.18), lineWidth: 5)

            Circle()
                .trim(from: 0, to: min(max(state.percentUsed, 0), 1))
                .stroke(state.tintColor, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90))

            Text(state.percentText)
                .font(.system(size: max(size * 0.24, 10), weight: .bold, design: .rounded))
                .foregroundStyle(state.tintColor)
                .minimumScaleFactor(0.65)
                .lineLimit(1)
        }
        .frame(width: size, height: size)
        .accessibilityLabel(Text(state.percentText))
    }
}

private struct BudgetAmountBlock: View {
    let state: BudgetActivityAttributes.ContentState
    let alignment: HorizontalAlignment

    var body: some View {
        VStack(alignment: alignment, spacing: 3) {
            Text(LocalizedStringKey(state.isOverLimit ? "liveActivity.budget.over" : "liveActivity.budget.remaining"))
                .font(.caption2)
                .foregroundStyle(.secondary)

            Text(state.isOverLimit ? state.overLimitText : state.remainingText)
                .font(.title3.weight(.bold))
                .foregroundStyle(state.tintColor)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
        .fixedSize(horizontal: true, vertical: false)
    }
}

private struct LiveActivityAppIcon: View {
    var size: CGFloat

    var body: some View {
        Text("¥")
            .font(.system(size: size * 0.68, weight: .heavy))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(hex: "#F6C343"))
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
    }
}

private struct WidgetFontAwesomeIcon: View {
    let name: String
    var size: CGFloat = 16

    init(name: String, size: CGFloat = 16) {
        self.name = name
        self.size = size
        WidgetFontAwesomeFontLoader.registerIfNeeded()
    }

    var body: some View {
        Text(WidgetAccountIconMapper.glyph(for: name))
            .font(.custom(WidgetAccountIconMapper.fontName(for: name), fixedSize: size))
            .accessibilityHidden(true)
    }
}
#endif

private struct WidgetHeader: View {
    let titleKey: LocalizedStringKey
    let systemImage: String

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: systemImage)
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(Color.accentColor, in: Circle())

            Text(titleKey)
                .font(.caption.weight(.semibold))
                .lineLimit(1)

            Spacer(minLength: 0)
        }
    }
}

private struct MetricChip: View {
    let titleKey: LocalizedStringKey
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(titleKey)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(color.opacity(0.11), in: RoundedRectangle(cornerRadius: 8))
    }
}

private extension View {
    func widgetContainerBackground() -> some View {
        containerBackground(for: .widget) {
            LinearGradient(
                colors: [
                    Color.widgetContainerGradientStart,
                    Color.widgetContainerGradientEnd
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

private extension Color {
    static let widgetContainerGradientStart = Color(UIColor { traits in
        if traits.userInterfaceStyle == .dark {
            return UIColor(red: 0.18, green: 0.15, blue: 0.08, alpha: 1)
        }

        return UIColor(red: 1, green: 0.96, blue: 0.84, alpha: 1)
    })

    static let widgetContainerGradientEnd = Color(UIColor { traits in
        if traits.userInterfaceStyle == .dark {
            return UIColor(red: 0.08, green: 0.08, blue: 0.07, alpha: 1)
        }

        return UIColor.systemBackground
    })
}

private extension WidgetRecordKind {
    var symbolName: String {
        switch self {
        case .expense:
            return "minus.circle.fill"
        case .income:
            return "plus.circle.fill"
        case .transfer:
            return "arrow.left.arrow.right.circle.fill"
        }
    }

    var tintColor: Color {
        switch self {
        case .expense:
            return .red
        case .income:
            return .green
        case .transfer:
            return .blue
        }
    }

    var liveActivityTitleKey: LocalizedStringKey {
        switch self {
        case .expense:
            return "liveActivity.kind.expense"
        case .income:
            return "liveActivity.kind.income"
        case .transfer:
            return "liveActivity.kind.transfer"
        }
    }
}

#if canImport(ActivityKit)
private extension RecentTransactionActivityAttributes.ContentState {
    var amountColor: Color {
        switch kind {
        case .expense:
            return .red
        case .income:
            return .green
        case .transfer:
            return .blue
        }
    }
}

private extension BudgetActivityAttributes.ContentState {
    var tintColor: Color {
        isOverLimit ? .red : .accentColor
    }

    var percentText: String {
        String(format: "%.0f%%", min(max(percentUsed, 0), 9.99) * 100)
    }

    var overLimitText: String {
        remainingText.replacingOccurrences(of: "-", with: "")
    }
}
#endif

private extension Color {
    init(hex: String) {
        let normalizedHex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: normalizedHex).scanHexInt64(&value)

        let red: UInt64
        let green: UInt64
        let blue: UInt64

        switch normalizedHex.count {
        case 6:
            red = (value & 0xFF0000) >> 16
            green = (value & 0x00FF00) >> 8
            blue = value & 0x0000FF
        default:
            red = 0xF6
            green = 0xC3
            blue = 0x43
        }

        self.init(
            .sRGB,
            red: Double(red) / 255,
            green: Double(green) / 255,
            blue: Double(blue) / 255,
            opacity: 1
        )
    }
}

#Preview("Quick Record", as: .systemSmall) {
    QuickRecordWidget()
} timeline: {
    LedgerWidgetEntry(date: Date(), snapshot: .empty)
}

#Preview("Quick Record Medium", as: .systemMedium) {
    QuickRecordWidget()
} timeline: {
    LedgerWidgetEntry(date: Date(), snapshot: .empty)
}

#Preview("Quick Record Large", as: .systemLarge) {
    QuickRecordWidget()
} timeline: {
    LedgerWidgetEntry(date: Date(), snapshot: .empty)
}

#Preview("Overview", as: .systemMedium) {
    LedgerOverviewWidget()
} timeline: {
    LedgerWidgetEntry(date: Date(), snapshot: .empty)
}

#Preview("Report Medium", as: .systemMedium) {
    LedgerReportWidget()
} timeline: {
    LedgerWidgetEntry(date: Date(), snapshot: .empty)
}

#Preview("Report", as: .systemLarge) {
    LedgerReportWidget()
} timeline: {
    LedgerWidgetEntry(date: Date(), snapshot: .empty)
}
