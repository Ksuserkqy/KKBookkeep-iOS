import SwiftUI

struct TransactionsPage: View {
    @EnvironmentObject private var draftStore: DraftBookkeepingStore

    var body: some View {
        NavigationStack {
            List {
                if let draft = draftStore.lastDraft {
                    Section {
                        VStack(alignment: .leading, spacing: 14) {
                            Label("transactions.draft.title", systemImage: "doc.badge.clock")
                                .font(.headline)

                            Text("transactions.draft.subtitle")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            VStack(alignment: .leading, spacing: 10) {
                                DraftSummaryRow(titleKey: "transactions.draft.kind", value: localizedTitle(for: draft.kind))
                                if draft.kind == .transfer {
                                    DraftSummaryRow(titleKey: "transactions.draft.transferOutAmount", value: draft.amountText)
                                    DraftSummaryRow(titleKey: "transactions.draft.transferInAmount", value: draft.transferInAmountText ?? draft.amountText)
                                } else {
                                    DraftSummaryRow(titleKey: "transactions.draft.amount", value: draft.amountText)
                                }
                                DraftSummaryRow(titleKey: "transactions.draft.dateTime", value: Self.dateFormatter.string(from: draft.date))

                                if let location = draft.location {
                                    DraftSummaryRow(titleKey: "transactions.draft.location", value: location.displayName)
                                }

                                if draft.kind == .transfer {
                                    DraftVisualSummaryRow(
                                        titleKey: "transactions.draft.fromAccount",
                                        item: accountItem(for: draft.fromAccountId)
                                    )
                                    DraftVisualSummaryRow(
                                        titleKey: "transactions.draft.toAccount",
                                        item: accountItem(for: draft.toAccountId)
                                    )
                                } else {
                                    DraftVisualSummaryRow(
                                        titleKey: "transactions.draft.category",
                                        item: categoryItem(for: draft.categoryId)
                                    )
                                    DraftVisualSummaryRow(
                                        titleKey: "transactions.draft.account",
                                        item: accountItem(for: draft.accountId)
                                    )
                                }

                                if !draft.note.isEmpty {
                                    DraftSummaryRow(titleKey: "transactions.draft.note", value: draft.note)
                                }
                            }
                            .font(.subheadline)
                        }
                        .padding(.vertical, 8)
                    } footer: {
                        Text("transactions.draft.footer")
                    }
                } else {
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

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}

private struct DraftSummaryRow: View {
    let titleKey: LocalizedStringKey
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(titleKey)
                .foregroundStyle(.secondary)

            Spacer(minLength: 16)

            Text(value)
                .multilineTextAlignment(.trailing)
        }
    }
}

private struct DraftVisualSummaryItem {
    let name: String
    let iconName: String
    let colorHex: String
}

private struct DraftVisualSummaryRow: View {
    let titleKey: LocalizedStringKey
    let item: DraftVisualSummaryItem

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(titleKey)
                .foregroundStyle(.secondary)

            Spacer(minLength: 16)

            HStack(spacing: 8) {
                DraftVisualBadge(iconName: item.iconName, colorHex: item.colorHex, size: 24)

                Text(item.name)
            }
            .multilineTextAlignment(.trailing)
        }
    }
}

#Preview {
    TransactionsPage()
        .environmentObject(DraftBookkeepingStore())
}
