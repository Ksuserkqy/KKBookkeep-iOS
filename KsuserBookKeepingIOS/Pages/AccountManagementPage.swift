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

                        Text(DraftAmountFormatter.currencyText(from: account.balanceText))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color(hex: account.colorHex))
                            .lineLimit(1)

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
            if draftStore.updateAccount(
                id: editingAccount.id,
                name: draft.name,
                type: draft.type,
                iconName: draft.iconName,
                colorHex: draft.colorHex,
                balanceText: draft.balanceText,
                note: draft.note
            ) {
                isEditorPresented = false
            }
        } else {
            if draftStore.addAccount(
                name: draft.name,
                type: draft.type,
                iconName: draft.iconName,
                colorHex: draft.colorHex,
                balanceText: draft.balanceText,
                note: draft.note
            ) {
                isEditorPresented = false
            }
        }
    }
}

private struct AccountEditorDraft {
    var name: String
    var type: DraftAccountType
    var iconName: String
    var colorHex: String
    var balanceText: String
    var note: String

    static let empty = AccountEditorDraft(
        name: "",
        type: .cash,
        iconName: DraftCustomizationOptions.accountIcons[0],
        colorHex: DraftCustomizationOptions.colors[0],
        balanceText: "0",
        note: ""
    )

    init(name: String, type: DraftAccountType, iconName: String, colorHex: String, balanceText: String, note: String) {
        self.name = name
        self.type = type
        self.iconName = iconName
        self.colorHex = colorHex
        self.balanceText = balanceText
        self.note = note
    }

    init(account: DraftAccount) {
        self.name = account.name
        self.type = account.type
        self.iconName = account.iconName
        self.colorHex = account.colorHex
        self.balanceText = account.balanceText
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

                    HStack {
                        Text("management.account.balance")

                        TextField("management.account.balance.placeholder", text: $draft.balanceText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .monospacedDigit()
                            .onChange(of: draft.balanceText) { _, newValue in
                                let sanitizedValue = DraftAmountFormatter.sanitizedNumericAmountText(newValue)
                                if sanitizedValue != newValue {
                                    draft.balanceText = sanitizedValue
                                }
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
                    DraftColorSelectionPicker(
                        colorHex: $draft.colorHex,
                        previewIconName: draft.iconName
                    )
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
                        .disabled(!draft.isSaveEnabled)
                }
            }
        }
    }
}

private extension AccountEditorDraft {
    var isSaveEnabled: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && DraftAmountFormatter.normalizedAmountText(balanceText, allowNegative: false) != nil
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
        "#64748B",
        "#EF4444",
        "#84CC16",
        "#14B8A6",
        "#6366F1",
        "#A855F7",
        "#F59E0B",
        "#0F172A"
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
        "weixin",
        "qq",
        "alipay",
        "apple-pay",
        "google-pay",
        "cc-visa",
        "cc-mastercard",
        "paypal",
        "coins",
        "piggy-bank",
        "sack-dollar",
        "vault",
        "cash-register",
        "file-invoice-dollar",
        "box-archive",
        "chart-pie",
        "chart-line",
        "circle-dollar-to-slot",
        "shield-halved",
        "wifi"
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
        "calendar-days",
        "clock",
        "camera",
        "headphones",
        "dumbbell",
        "film",
        "map-location-dot",
        "bell",
        "gear",
        "heart",
        "star",
        "building",
        "weixin",
        "qq",
        "weibo",
        "alipay",
        "wifi",
        "paw",
        "palette",
        "briefcase",
        "gift",
        "file-lines",
        "receipt"
    ]
}

struct DraftColorSelectionPicker: View {
    @Binding var colorHex: String
    let previewIconName: String

    private let columns = [
        GridItem(.adaptive(minimum: 40), spacing: 10)
    ]

    private var colorSelection: Binding<Color> {
        Binding(
            get: {
                Color(hex: colorHex)
            },
            set: { newColor in
                colorHex = newColor.hexString
            }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                DraftVisualBadge(iconName: previewIconName, colorHex: colorHex, size: 44)

                VStack(alignment: .leading, spacing: 3) {
                    Text("management.color.preview")
                        .font(.subheadline.weight(.semibold))

                    Text(colorHex.uppercased())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }

                Spacer()

                ColorPicker(
                    "management.color.custom",
                    selection: colorSelection,
                    supportsOpacity: false
                )
                .labelsHidden()
                .accessibilityLabel(Text("management.color.custom"))
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("management.color.presets")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(DraftCustomizationOptions.colors, id: \.self) { presetColorHex in
                        Button {
                            colorHex = presetColorHex
                        } label: {
                            Circle()
                                .fill(Color(hex: presetColorHex))
                                .frame(width: 34, height: 34)
                                .overlay {
                                    Circle()
                                        .stroke(
                                            colorHex.caseInsensitiveCompare(presetColorHex) == .orderedSame
                                                ? Color.primary
                                                : Color.clear,
                                            lineWidth: 2
                                        )
                                }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text(presetColorHex))
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct IconGridPicker: View {
    @Binding var selectedIconName: String
    let colorHex: String
    let iconNames: [String]
    @State private var isAllIconsPresented = false

    private let columns = [
        GridItem(.adaptive(minimum: 48), spacing: 10)
    ]

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
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
            .padding(.bottom, 56)

            Button {
                isAllIconsPresented = true
            } label: {
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 54, height: 54)
                        .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 5)

                    DraftVisualBadge(iconName: "ellipsis", colorHex: colorHex, size: 46)
                        .overlay {
                            Circle()
                                .stroke(Color.accentColor, lineWidth: 2)
                        }
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("management.icon.more"))
            .padding(.trailing, 2)
            .padding(.bottom, 8)
        }
        .sheet(isPresented: $isAllIconsPresented) {
            FontAwesomeIconSearchSheet(
                selectedIconName: $selectedIconName,
                colorHex: colorHex
            )
        }
    }
}

private struct FontAwesomeIconSearchSheet: View {
    @Binding var selectedIconName: String
    let colorHex: String

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var selectedCategoryId = FontAwesomeIconCatalog.allCategoryId

    private let columns = [
        GridItem(.adaptive(minimum: 64), spacing: 12)
    ]

    private var visibleIcons: [FontAwesomeIconMetadata] {
        FontAwesomeIconCatalog.allIcons.filter { icon in
            let matchesCategory: Bool
            if selectedCategoryId == FontAwesomeIconCatalog.brandCategoryId {
                matchesCategory = icon.style == .brands
            } else {
                matchesCategory = selectedCategoryId == FontAwesomeIconCatalog.allCategoryId
                    || icon.categories.contains(selectedCategoryId)
            }
            let matchesSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || icon.matches(searchText)

            return matchesCategory && matchesSearch
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "info.circle.fill")
                        .foregroundStyle(Color.accentColor)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(
                            String(
                                format: NSLocalizedString("management.icon.notice.version", comment: ""),
                                FontAwesomeIconCatalog.version
                            )
                        )
                        .font(.subheadline.weight(.semibold))

                        Link("management.icon.notice.link", destination: FontAwesomeIconCatalog.websiteURL)
                            .font(.caption.weight(.semibold))
                    }

                    Spacer()
                }
                .padding(12)
                .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 4)

                HStack {
                    Text("management.icon.category")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Spacer()

                    Picker("management.icon.category", selection: $selectedCategoryId) {
                        Text("management.icon.category.all")
                            .tag(FontAwesomeIconCatalog.allCategoryId)

                        Text("management.icon.category.brands")
                            .tag(FontAwesomeIconCatalog.brandCategoryId)

                        ForEach(FontAwesomeIconCatalog.allCategories) { category in
                            Text(localizedCategoryName(for: category.id))
                                .tag(category.id)
                        }
                    }
                    .pickerStyle(.menu)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

                ScrollView {
                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(visibleIcons) { icon in
                            Button {
                                selectedIconName = icon.name
                                dismiss()
                            } label: {
                                VStack(spacing: 6) {
                                    DraftVisualBadge(iconName: icon.name, colorHex: colorHex, size: 44)
                                        .overlay {
                                            if selectedIconName == icon.name {
                                                Circle()
                                                    .stroke(Color.accentColor, lineWidth: 2)
                                            }
                                        }

                                    Text(icon.name)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle(Text("management.icon.all"))
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: Text("management.icon.search.placeholder"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func localizedCategoryName(for categoryId: String) -> String {
        NSLocalizedString("management.icon.category.\(categoryId)", comment: "")
    }
}

#Preview {
    NavigationStack {
        AccountManagementPage()
            .environmentObject(DraftBookkeepingStore())
    }
}
