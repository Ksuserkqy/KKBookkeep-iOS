import SwiftUI

enum TransactionDateFilterMode: String, CaseIterable, Identifiable {
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

enum TransactionDateRangeUnit: String, CaseIterable, Identifiable {
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

struct TransactionDateFilter: Equatable {
    var mode: TransactionDateFilterMode = .month
    var rangeUnit: TransactionDateRangeUnit = .day
    var referenceDate: Date = Date()
    var rangeStart: Date = Date()
    var rangeEnd: Date = Date()

    func contains(_ date: Date, calendar: Calendar = .current) -> Bool {
        let interval = dateInterval(calendar: calendar)
        return date >= interval.start && date < interval.end
    }

    func dateInterval(calendar: Calendar = .current) -> DateInterval {
        switch mode {
        case .day:
            return calendar.dateInterval(of: .day, for: referenceDate)
                ?? fallbackInterval(endingAt: referenceDate, days: 1, calendar: calendar)
        case .month:
            return calendar.dateInterval(of: .month, for: referenceDate)
                ?? fallbackInterval(endingAt: referenceDate, days: 30, calendar: calendar)
        case .year:
            return calendar.dateInterval(of: .year, for: referenceDate)
                ?? fallbackInterval(endingAt: referenceDate, days: 365, calendar: calendar)
        case .range:
            let interval = normalizedRangeInterval(calendar: calendar)
            return DateInterval(start: interval.start, end: interval.end)
        }
    }

    func previousDateInterval(calendar: Calendar = .current) -> DateInterval {
        let interval = dateInterval(calendar: calendar)

        switch mode {
        case .day, .month, .year:
            let component = mode.component
            let start = calendar.date(byAdding: component, value: -1, to: interval.start)
                ?? interval.start
            let end = calendar.date(byAdding: component, value: -1, to: interval.end)
                ?? interval.end
            return DateInterval(start: start, end: end)
        case .range:
            let component = rangeUnit.component
            let periodCount = normalizedRangePeriodCount(calendar: calendar)
            let start = calendar.date(byAdding: component, value: -periodCount, to: interval.start)
                ?? interval.start
            let end = calendar.date(byAdding: component, value: -periodCount, to: interval.end)
                ?? interval.end
            return DateInterval(start: start, end: end)
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
            referenceDate = calendar.date(byAdding: .day, value: value, to: referenceDate)
                ?? referenceDate
        case .month:
            referenceDate = calendar.date(byAdding: .month, value: value, to: referenceDate)
                ?? referenceDate
        case .year:
            referenceDate = calendar.date(byAdding: .year, value: value, to: referenceDate)
                ?? referenceDate
        case .range:
            let component = rangeUnit.component
            rangeStart = calendar.date(byAdding: component, value: value, to: rangeStart)
                ?? rangeStart
            rangeEnd = calendar.date(byAdding: component, value: value, to: rangeEnd)
                ?? rangeEnd
        }
    }

    func summaryText(calendar: Calendar = .current) -> String {
        switch mode {
        case .day:
            return Self.localizedDateText(referenceDate, template: "yMMMd")
        case .month:
            return Self.localizedDateText(referenceDate, template: "yMMMM")
        case .year:
            return Self.localizedDateText(referenceDate, template: "y")
        case .range:
            let interval = normalizedRangeBounds(calendar: calendar)
            return "\(rangeText(for: interval.start, unit: rangeUnit)) - \(rangeText(for: interval.end, unit: rangeUnit))"
        }
    }

    private func rangeText(for date: Date, unit: TransactionDateRangeUnit) -> String {
        switch unit {
        case .day:
            return Self.localizedDateText(date, template: "yMMMd")
        case .month:
            return Self.localizedDateText(date, template: "yMMMM")
        case .year:
            return Self.localizedDateText(date, template: "y")
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

    private func normalizedRangePeriodCount(calendar: Calendar) -> Int {
        let interval = normalizedRangeInterval(calendar: calendar)

        switch rangeUnit {
        case .day:
            return max(
                1,
                calendar.dateComponents([.day], from: interval.start, to: interval.end).day ?? 1
            )
        case .month:
            return max(
                1,
                calendar.dateComponents([.month], from: interval.start, to: interval.end).month ?? 1
            )
        case .year:
            return max(
                1,
                calendar.dateComponents([.year], from: interval.start, to: interval.end).year ?? 1
            )
        }
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

    private func fallbackInterval(
        endingAt date: Date,
        days: Int,
        calendar: Calendar
    ) -> DateInterval {
        let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: date)) ?? date
        let start = calendar.date(byAdding: .day, value: -days, to: end) ?? date
        return DateInterval(start: start, end: end)
    }

    private static func localizedDateText(_ date: Date, template: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = AppLocalization.locale
        formatter.dateFormat = DateFormatter.dateFormat(fromTemplate: template, options: 0, locale: AppLocalization.locale)
        return formatter.string(from: date)
    }
}

struct TransactionDateHeader: View {
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
