import SwiftUI

struct AccountManagementPage: View {
    @EnvironmentObject private var draftStore: DraftBookkeepingStore
    @State private var editingAccount: DraftAccount?
    @State private var draft = AccountEditorDraft.empty
    @State private var isEditorPresented = false

    var body: some View {
        Form {
            if let messageKey = draftStore.messageKey {
                Section {
                    Text(LocalizedStringKey(messageKey))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                ForEach(draftStore.accounts) { account in
                    HStack(spacing: 12) {
                        DraftVisualBadge(iconName: account.iconName, colorHex: account.colorHex)

                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Text(account.name)

                                if account.isDefault {
                                    Text("management.defaultBadge")
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Text(account.type.titleKey)
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            if !account.note.isEmpty {
                                Text(account.note)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }

                        Spacer()

                        Button {
                            beginEditing(account)
                        } label: {
                            Image(systemName: "pencil")
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel(Text("management.action.edit"))

                        Button(role: .destructive) {
                            _ = draftStore.deleteAccount(id: account.id)
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel(Text("management.action.delete"))
                    }
                    .padding(.vertical, 4)
                }
            } header: {
                Text("management.account.section")
            } footer: {
                Text("management.account.footer")
            }

            Section {
                Button {
                    beginAdding()
                } label: {
                    Label("management.account.add", systemImage: "plus.circle.fill")
                }
            }
        }
        .navigationTitle(Text("management.account.title"))
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                AppBackButton()
            }
        }
        .sheet(isPresented: $isEditorPresented) {
            AccountEditorSheet(
                isEditing: editingAccount != nil,
                draft: $draft,
                onCancel: {
                    isEditorPresented = false
                },
                onSave: {
                    saveAccount()
                }
            )
        }
    }

    private func beginAdding() {
        editingAccount = nil
        draft = .empty
        isEditorPresented = true
    }

    private func beginEditing(_ account: DraftAccount) {
        editingAccount = account
        draft = AccountEditorDraft(account: account)
        isEditorPresented = true
    }

    private func saveAccount() {
        if let editingAccount {
            draftStore.updateAccount(
                id: editingAccount.id,
                name: draft.name,
                type: draft.type,
                iconName: draft.iconName,
                colorHex: draft.colorHex,
                note: draft.note
            )
        } else {
            draftStore.addAccount(
                name: draft.name,
                type: draft.type,
                iconName: draft.iconName,
                colorHex: draft.colorHex,
                note: draft.note
            )
        }

        isEditorPresented = false
    }
}

private struct AccountEditorDraft {
    var name: String
    var type: DraftAccountType
    var iconName: String
    var colorHex: String
    var note: String

    static let empty = AccountEditorDraft(
        name: "",
        type: .cash,
        iconName: DraftCustomizationOptions.accountIcons[0],
        colorHex: DraftCustomizationOptions.colors[0],
        note: ""
    )

    init(name: String, type: DraftAccountType, iconName: String, colorHex: String, note: String) {
        self.name = name
        self.type = type
        self.iconName = iconName
        self.colorHex = colorHex
        self.note = note
    }

    init(account: DraftAccount) {
        self.name = account.name
        self.type = account.type
        self.iconName = account.iconName
        self.colorHex = account.colorHex
        self.note = account.note
    }
}

private struct AccountEditorSheet: View {
    let isEditing: Bool
    @Binding var draft: AccountEditorDraft
    let onCancel: () -> Void
    let onSave: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 12) {
                        DraftVisualBadge(iconName: draft.iconName, colorHex: draft.colorHex, size: 44)

                        TextField("management.account.name.placeholder", text: $draft.name)
                    }

                    Picker("management.account.type", selection: $draft.type) {
                        ForEach(DraftAccountType.allCases) { type in
                            Text(type.titleKey).tag(type)
                        }
                    }
                } header: {
                    Text("management.account.section.basic")
                }

                Section {
                    IconGridPicker(
                        selectedIconName: $draft.iconName,
                        colorHex: draft.colorHex,
                        iconNames: DraftCustomizationOptions.accountIcons
                    )
                } header: {
                    Text("management.icon")
                }

                Section {
                    Picker("management.color", selection: $draft.colorHex) {
                        ForEach(DraftCustomizationOptions.colors, id: \.self) { colorHex in
                            HStack {
                                Circle()
                                    .fill(Color(hex: colorHex))
                                    .frame(width: 16, height: 16)

                                Text(colorHex)
                            }
                            .tag(colorHex)
                        }
                    }
                } header: {
                    Text("management.section.appearance")
                }

                Section {
                    TextField("management.account.note.placeholder", text: $draft.note, axis: .vertical)
                        .lineLimit(2...4)
                } header: {
                    Text("management.account.section.note")
                }
            }
            .navigationTitle(Text(LocalizedStringKey(isEditing ? "management.account.edit.title" : "management.account.add.title")))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel", action: onCancel)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("common.save", action: onSave)
                        .disabled(draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

enum DraftCustomizationOptions {
    static let colors = [
        "#F6C343",
        "#F97316",
        "#22C55E",
        "#3B82F6",
        "#8B5CF6",
        "#EC4899",
        "#06B6D4",
                "#64748B"
    ]

    static let accountIcons = [
        "money-bill",
        "money-bill-wave",
        "money-check-dollar",
        "credit-card",
        "wallet",
        "building-columns",
        "landmark",
        "mobile-screen-button",
        "coins",
        "piggy-bank",
        "sack-dollar",
        "file-invoice-dollar",
        "box-archive",
        "chart-pie",
        "circle-dollar-to-slot",
        "shield-halved",
        "wifi",
        "ellipsis"
    ]

    static let categoryIcons = [
        "utensils",
        "burger",
        "mug-saucer",
        "bus",
        "train-subway",
        "car",
        "gas-pump",
        "plane",
        "truck-fast",
        "bag-shopping",
        "basket-shopping",
        "cart-shopping",
        "store",
        "shirt",
        "house",
        "heart-pulse",
        "gamepad",
        "book",
        "graduation-cap",
        "phone",
        "wifi",
        "paw",
        "palette",
        "briefcase",
        "gift",
        "file-lines",
        "receipt",
        "ellipsis"
    ]
}

struct IconGridPicker: View {
    @Binding var selectedIconName: String
    let colorHex: String
    let iconNames: [String]

    private let columns = [
        GridItem(.adaptive(minimum: 48), spacing: 10)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(iconNames, id: \.self) { iconName in
                Button {
                    selectedIconName = iconName
                } label: {
                    DraftVisualBadge(iconName: iconName, colorHex: colorHex, size: 42)
                        .overlay {
                            if selectedIconName == iconName {
                                Circle()
                                    .stroke(Color.accentColor, lineWidth: 2)
                            }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(iconName))
            }
        }
        .padding(.vertical, 6)
    }
}

#Preview {
    NavigationStack {
        AccountManagementPage()
            .environmentObject(DraftBookkeepingStore())
    }
}
