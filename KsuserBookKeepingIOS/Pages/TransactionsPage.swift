import SwiftUI

struct TransactionsPage: View {
    @EnvironmentObject private var draftStore: DraftBookkeepingStore

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
                        ForEach(draftStore.transactions) { transaction in
                            TransactionSummaryCard(
                                transaction: transaction,
                                localizedTitle: localizedTitle(for: transaction.kind),
                                accountItem: accountItem(for: transaction),
                                categoryItem: categoryItem(for: transaction),
                                dateText: Self.dateFormatter.string(from: transaction.date)
                            )
                            .padding(.vertical, 6)
                        }
                    } footer: {
                        Text("transactions.footer.localOnly")
                    }
                }
            }
            .navigationTitle(Text("tab.transactions"))
        }
    }

    private func localizedTitle(for kind: DraftEntryKind) -> String {
        NSLocalizedString(kind.localizationKey, comment: "")
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

        return DraftVisualSummaryItem(name: account.name, iconName: account.iconName, colorHex: account.colorHex)
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
            name: draftStore.categoryDisplayName(for: category.id),
            iconName: category.iconName,
            colorHex: category.colorHex
        )
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

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}

private struct TransactionSummaryCard: View {
    let transaction: DraftTransaction
    let localizedTitle: String
    let accountItem: DraftVisualSummaryItem
    let categoryItem: DraftVisualSummaryItem
    let dateText: String

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
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                DraftVisualBadge(iconName: categoryItem.iconName, colorHex: categoryItem.colorHex, size: 34)

                VStack(alignment: .leading, spacing: 3) {
                    Text(categoryItem.name)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)

                    Text(localizedTitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 12)

                Text(amountText)
                    .font(.headline)
                    .foregroundStyle(amountColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }

            HStack(spacing: 8) {
                DraftVisualBadge(iconName: accountItem.iconName, colorHex: accountItem.colorHex, size: 22)

                Text(accountItem.name)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer(minLength: 8)

                Text(dateText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let location = transaction.location {
                Label(location.displayName, systemImage: "location.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            if !transaction.note.isEmpty {
                Text(transaction.note)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
    }
}

private struct DraftVisualSummaryItem {
    let name: String
    let iconName: String
    let colorHex: String
}

#Preview {
    TransactionsPage()
        .environmentObject(DraftBookkeepingStore())
}
