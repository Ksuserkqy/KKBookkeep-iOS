import Foundation

#if canImport(ActivityKit)
import ActivityKit
#endif

@MainActor
enum RecentTransactionLiveActivityManager {
    static var isFeatureEnabled: Bool {
        UserDefaults.standard.object(forKey: WidgetSharedConfiguration.liveActivitiesEnabledKey) as? Bool ?? false
    }

    static var isBudgetFeatureEnabled: Bool {
        UserDefaults.standard.object(forKey: WidgetSharedConfiguration.budgetLiveActivitiesEnabledKey) as? Bool ?? true
    }

    static var selectedBudgetId: String {
        UserDefaults.standard.string(forKey: WidgetSharedConfiguration.selectedBudgetLiveActivityIdKey) ?? ""
    }

    static var displayDurationSeconds: TimeInterval {
        let storedValue = UserDefaults.standard.integer(forKey: WidgetSharedConfiguration.liveActivityDisplayDurationKey)
        let allowedValues = [5, 10, 30, 60]
        let seconds = allowedValues.contains(storedValue) ? storedValue : 10

        return TimeInterval(seconds)
    }

    static func setFeatureEnabled(_ isEnabled: Bool) {
        UserDefaults.standard.set(isEnabled, forKey: WidgetSharedConfiguration.liveActivitiesEnabledKey)

        if isEnabled {
            UserDefaults.standard.set(false, forKey: WidgetSharedConfiguration.budgetLiveActivitiesEnabledKey)
        }

        guard !isEnabled else { return }

        Task {
            await endRecentTransactionActivities()
        }
    }

    static func setBudgetFeatureEnabled(_ isEnabled: Bool) {
        UserDefaults.standard.set(isEnabled, forKey: WidgetSharedConfiguration.budgetLiveActivitiesEnabledKey)

        if isEnabled {
            UserDefaults.standard.set(false, forKey: WidgetSharedConfiguration.liveActivitiesEnabledKey)
        }

        guard !isEnabled else { return }

        Task {
            await endBudgetActivities()
        }
    }

    static func setSelectedBudgetId(_ budgetId: String) {
        UserDefaults.standard.set(budgetId, forKey: WidgetSharedConfiguration.selectedBudgetLiveActivityIdKey)
    }

    static func showRecentTransaction(
        _ transaction: DraftTransaction,
        accounts: [DraftAccount],
        categoryName: String
    ) {
        guard isFeatureEnabled else { return }

        #if canImport(ActivityKit)
        guard #available(iOS 16.2, *) else { return }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let state = makeState(
            for: transaction,
            accounts: accounts,
            categoryName: categoryName
        )
        let attributes = RecentTransactionActivityAttributes(ledgerId: "default")
        let content = ActivityContent(
            state: state,
            staleDate: Date().addingTimeInterval(displayDurationSeconds),
            relevanceScore: 100
        )
        let displayDuration = displayDurationSeconds

        Task {
            await endAll()

            do {
                let activity = try Activity<RecentTransactionActivityAttributes>.request(
                    attributes: attributes,
                    content: content,
                    pushType: nil
                )
                scheduleEnd(activity, after: displayDuration)
            } catch {
                // Live Activities can be unavailable because of system settings, device support, or quota limits.
            }
        }
        #endif
    }

    static func showBudgetUsage(
        usage: DraftBudgetUsage,
        transaction: DraftTransaction,
        transactionTitle: String
    ) {
        guard isBudgetFeatureEnabled else { return }

        #if canImport(ActivityKit)
        guard #available(iOS 16.2, *) else { return }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let state = makeBudgetState(
            usage: usage,
            transaction: transaction,
            transactionTitle: transactionTitle
        )
        let attributes = BudgetActivityAttributes(ledgerId: "default")
        let content = ActivityContent(
            state: state,
            staleDate: Date().addingTimeInterval(displayDurationSeconds),
            relevanceScore: 100
        )
        let displayDuration = displayDurationSeconds

        Task {
            await endAll()

            do {
                let activity = try Activity<BudgetActivityAttributes>.request(
                    attributes: attributes,
                    content: content,
                    pushType: nil
                )
                scheduleEnd(activity, after: displayDuration)
            } catch {
                // Live Activities can be unavailable because of system settings, device support, or quota limits.
            }
        }
        #endif
    }

    static func endAll() async {
        await endRecentTransactionActivities()
        await endBudgetActivities()
    }

    static func endRecentTransactionActivities() async {
        #if canImport(ActivityKit)
        guard #available(iOS 16.2, *) else { return }

        for activity in Activity<RecentTransactionActivityAttributes>.activities {
            await activity.end(activity.content, dismissalPolicy: .immediate)
        }
        #endif
    }

    static func endBudgetActivities() async {
        #if canImport(ActivityKit)
        guard #available(iOS 16.2, *) else { return }

        for activity in Activity<BudgetActivityAttributes>.activities {
            await activity.end(activity.content, dismissalPolicy: .immediate)
        }
        #endif
    }

    #if canImport(ActivityKit)
    @available(iOS 16.2, *)
    private static func scheduleEnd<Attributes: ActivityAttributes>(
        _ activity: Activity<Attributes>,
        after displayDuration: TimeInterval
    ) {
        Task {
            let nanoseconds = UInt64(max(displayDuration, 1) * 1_000_000_000)
            try? await Task.sleep(nanoseconds: nanoseconds)

            await activity.end(activity.content, dismissalPolicy: .immediate)
        }
    }

    @available(iOS 16.2, *)
    private static func makeState(
        for transaction: DraftTransaction,
        accounts: [DraftAccount],
        categoryName: String
    ) -> RecentTransactionActivityAttributes.ContentState {
        let account = primaryAccount(for: transaction, accounts: accounts)
        let counterpartyAccountName = counterpartyAccountName(for: transaction, accounts: accounts)
        let fallbackAccountName = NSLocalizedString("draft.item.missing", comment: "")
        let dateText = Self.dateFormatter.string(from: transaction.date)
        let amountText = signedCurrencyText(
            for: transaction
        )

        return RecentTransactionActivityAttributes.ContentState(
            transactionId: transaction.id,
            kind: WidgetRecordKind(rawValue: transaction.kind.rawValue) ?? .expense,
            title: title(for: transaction, categoryName: categoryName, accounts: accounts),
            amountText: amountText,
            accountName: account?.name ?? fallbackAccountName,
            accountIconName: account?.iconName ?? "wallet",
            accountSymbolName: WidgetAccountIconMapper.systemImageName(for: account?.iconName ?? "wallet"),
            accountColorHex: account?.colorHex ?? "#F6C343",
            categoryName: transaction.kind == .transfer ? nil : categoryName,
            counterpartyAccountName: counterpartyAccountName,
            note: transaction.note,
            locationName: transaction.location?.displayName,
            dateText: dateText
        )
    }

    private static func primaryAccount(for transaction: DraftTransaction, accounts: [DraftAccount]) -> DraftAccount? {
        let accountId: String?
        switch transaction.kind {
        case .expense, .income:
            accountId = transaction.accountId
        case .transfer:
            accountId = transaction.fromAccountId
        }

        guard let accountId else { return nil }
        return accounts.first { $0.id == accountId }
    }

    private static func counterpartyAccountName(for transaction: DraftTransaction, accounts: [DraftAccount]) -> String? {
        guard transaction.kind == .transfer, let toAccountId = transaction.toAccountId else { return nil }

        return accounts.first { $0.id == toAccountId }?.name
    }

    private static func title(
        for transaction: DraftTransaction,
        categoryName: String,
        accounts: [DraftAccount]
    ) -> String {
        switch transaction.kind {
        case .expense, .income:
            return categoryName
        case .transfer:
            let fromName = primaryAccount(for: transaction, accounts: accounts)?.name
                ?? NSLocalizedString("draft.item.missing", comment: "")
            let toName = counterpartyAccountName(for: transaction, accounts: accounts)
                ?? NSLocalizedString("draft.item.missing", comment: "")
            return "\(fromName) -> \(toName)"
        }
    }

    private static func signedCurrencyText(for transaction: DraftTransaction) -> String {
        let amountText = DraftAmountFormatter.currencyText(from: transaction.amountText)

        switch transaction.kind {
        case .expense:
            return "-\(amountText)"
        case .income:
            return "+\(amountText)"
        case .transfer:
            return amountText
        }
    }

    @available(iOS 16.2, *)
    private static func makeBudgetState(
        usage: DraftBudgetUsage,
        transaction: DraftTransaction,
        transactionTitle: String
    ) -> BudgetActivityAttributes.ContentState {
        BudgetActivityAttributes.ContentState(
            budgetId: usage.budget.id,
            title: usage.budget.name.isEmpty ? usage.targetName : usage.budget.name,
            targetName: usage.targetName,
            spentText: DraftAmountFormatter.currencyText(from: usage.spentText),
            limitText: DraftAmountFormatter.currencyText(from: usage.limitText),
            remainingText: DraftAmountFormatter.currencyText(from: usage.remainingText),
            percentUsed: usage.percentUsed,
            isOverLimit: usage.isOverLimit,
            transactionAmountText: "-\(DraftAmountFormatter.currencyText(from: transaction.amountText))",
            transactionTitle: transactionTitle,
            dateText: dateFormatter.string(from: transaction.date)
        )
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("MdHm")
        return formatter
    }()
    #endif
}
