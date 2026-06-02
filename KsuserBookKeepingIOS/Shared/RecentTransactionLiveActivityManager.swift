import Foundation

#if canImport(ActivityKit)
import ActivityKit
#endif

@MainActor
enum RecentTransactionLiveActivityManager {
    static var isFeatureEnabled: Bool {
        UserDefaults.standard.object(forKey: WidgetSharedConfiguration.liveActivitiesEnabledKey) as? Bool ?? true
    }

    static func setFeatureEnabled(_ isEnabled: Bool) {
        UserDefaults.standard.set(isEnabled, forKey: WidgetSharedConfiguration.liveActivitiesEnabledKey)

        guard !isEnabled else { return }

        Task {
            await endAll()
        }
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
            staleDate: Date().addingTimeInterval(60 * 60),
            relevanceScore: 100
        )

        Task {
            await endAll()

            do {
                _ = try Activity<RecentTransactionActivityAttributes>.request(
                    attributes: attributes,
                    content: content,
                    pushType: nil
                )
            } catch {
                // Live Activities can be unavailable because of system settings, device support, or quota limits.
            }
        }
        #endif
    }

    static func endAll() async {
        #if canImport(ActivityKit)
        guard #available(iOS 16.2, *) else { return }

        for activity in Activity<RecentTransactionActivityAttributes>.activities {
            await activity.end(activity.content, dismissalPolicy: .immediate)
        }
        #endif
    }

    #if canImport(ActivityKit)
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

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("MdHm")
        return formatter
    }()
    #endif
}
