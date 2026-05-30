import SwiftUI

struct CategoryManagementPage: View {
    @EnvironmentObject private var draftStore: DraftBookkeepingStore
    @State private var selectedKind = DraftEntryKind.expense
    @State private var editingCategory: DraftCategory?
    @State private var deletingCategory: DraftCategory?
    @State private var draft = CategoryEditorDraft.empty
    @State private var isEditorPresented = false

    var body: some View {
        Form {
            Section {
                Picker("management.category.kind", selection: $selectedKind) {
                    Label("record.kind.expense", systemImage: "minus.circle.fill")
                        .labelStyle(.titleAndIcon)
                        .tag(DraftEntryKind.expense)
                    Label("record.kind.income", systemImage: "plus.circle.fill")
                        .labelStyle(.titleAndIcon)
                        .tag(DraftEntryKind.income)
                }
                .pickerStyle(.segmented)
            }

            Section {
                Button {
                    beginAdding()
                } label: {
                    Label("management.category.add", systemImage: "plus.circle.fill")
                }
            }

            if let messageKey = draftStore.messageKey {
                Section {
                    Text(LocalizedStringKey(messageKey))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                ForEach(draftStore.categoryHierarchyItems(for: selectedKind)) { item in
                    let category = item.category

                    HStack(spacing: 12) {
                        Spacer()
                            .frame(width: CGFloat(item.depth - 1) * 24)

                        DraftVisualBadge(iconName: category.iconName, colorHex: category.colorHex)

                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Text(category.name)

                                if category.isDefault {
                                    Text("management.defaultBadge")
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                }
                            }

                            if item.depth > 1 {
                                Text(levelTitleKey(for: item.depth))
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Spacer()

                        Button {
                            beginEditing(category)
                        } label: {
                            Image(systemName: "pencil")
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel(Text("management.action.edit"))

                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            deletingCategory = category
                        } label: {
                            Label("management.action.delete", systemImage: "trash")
                        }
                        .tint(.red)

                        if !category.isDefault, category.parentId == nil {
                            Button {
                                draftStore.setDefaultCategory(id: category.id)
                            } label: {
                                Label("management.action.setDefault", systemImage: "checkmark.circle")
                            }
                            .tint(.accentColor)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .onMove { source, destination in
                    draftStore.moveCategories(kind: selectedKind, from: source, to: destination)
                }
            } header: {
                Text("management.category.section")
            } footer: {
                Text("management.category.footer.sort")
            }
        }
        .navigationTitle(Text("management.category.title"))
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                AppBackButton()
            }

            ToolbarItem(placement: .topBarTrailing) {
                EditButton()
            }
        }
        .sheet(isPresented: $isEditorPresented) {
            CategoryEditorSheet(
                isEditing: editingCategory != nil,
                kind: selectedKind,
                parentItems: draftStore.selectableParentItems(for: selectedKind, excluding: editingCategory?.id),
                draft: $draft,
                onCancel: {
                    isEditorPresented = false
                },
                onSave: {
                    saveCategory()
                }
            )
        }
        .confirmationDialog(
            Text("management.category.delete.confirm.title"),
            isPresented: Binding(
                get: { deletingCategory != nil },
                set: { isPresented in
                    if !isPresented {
                        deletingCategory = nil
                    }
                }
            ),
            titleVisibility: .visible
        ) {
            Button("management.action.delete", role: .destructive) {
                deletePendingCategory()
            }

            Button("common.cancel", role: .cancel) {
                deletingCategory = nil
            }
        } message: {
            Text(deleteConfirmationMessageKey)
        }
    }

    private var deleteConfirmationMessageKey: LocalizedStringKey {
        guard
            let deletingCategory,
            draftStore.hasChildCategories(id: deletingCategory.id)
        else {
            return "management.category.delete.confirm.message"
        }

        return "management.category.delete.confirm.message.withChildren"
    }

    private func beginAdding() {
        editingCategory = nil
        draft = .empty
        isEditorPresented = true
    }

    private func beginEditing(_ category: DraftCategory) {
        editingCategory = category
        draft = CategoryEditorDraft(category: category)
        isEditorPresented = true
    }

    private func saveCategory() {
        if let editingCategory {
            if draftStore.updateCategory(
                id: editingCategory.id,
                name: draft.name,
                parentId: draft.parentId,
                iconName: draft.iconName,
                colorHex: draft.colorHex
            ) {
                isEditorPresented = false
            }
        } else {
            if draftStore.addCategory(
                name: draft.name,
                kind: selectedKind,
                parentId: draft.parentId,
                iconName: draft.iconName,
                colorHex: draft.colorHex
            ) {
                isEditorPresented = false
            }
        }
    }

    private func deletePendingCategory() {
        guard let deletingCategory else {
            return
        }

        _ = draftStore.deleteCategory(id: deletingCategory.id)
        self.deletingCategory = nil
    }

    private func levelTitleKey(for depth: Int) -> LocalizedStringKey {
        switch depth {
        case 2:
            return "management.category.level.second"
        case 3:
            return "management.category.level.third"
        default:
            return "management.category.level.first"
        }
    }
}

private struct CategoryEditorDraft {
    var name: String
    var parentId: String?
    var iconName: String
    var colorHex: String

    static let empty = CategoryEditorDraft(
        name: "",
        parentId: nil,
        iconName: DraftCustomizationOptions.categoryIcons[0],
        colorHex: DraftCustomizationOptions.colors[0]
    )

    init(name: String, parentId: String?, iconName: String, colorHex: String) {
        self.name = name
        self.parentId = parentId
        self.iconName = iconName
        self.colorHex = colorHex
    }

    init(category: DraftCategory) {
        self.name = category.name
        self.parentId = category.parentId
        self.iconName = category.iconName
        self.colorHex = category.colorHex
    }
}

private struct CategoryEditorSheet: View {
    @EnvironmentObject private var draftStore: DraftBookkeepingStore

    let isEditing: Bool
    let kind: DraftEntryKind
    let parentItems: [DraftCategoryHierarchyItem]
    @Binding var draft: CategoryEditorDraft
    let onCancel: () -> Void
    let onSave: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 12) {
                        DraftVisualBadge(iconName: draft.iconName, colorHex: draft.colorHex, size: 44)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(kind.titleKey)
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            TextField("management.category.name.placeholder", text: $draft.name)
                        }
                    }
                } header: {
                    Text("management.category.section.basic")
                }

                Section {
                    Picker("management.category.parent", selection: $draft.parentId) {
                        Text("management.category.parent.none")
                            .tag(Optional<String>.none)

                        ForEach(parentItems) { item in
                            Text(parentOptionTitle(for: item))
                                .tag(Optional(item.category.id))
                        }
                    }
                } footer: {
                    Text("management.category.parent.footer")
                }

                Section {
                    IconGridPicker(
                        selectedIconName: $draft.iconName,
                        colorHex: draft.colorHex,
                        iconNames: DraftCustomizationOptions.categoryIcons
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
            }
            .navigationTitle(Text(LocalizedStringKey(isEditing ? "management.category.edit.title" : "management.category.add.title")))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: onCancel) {
                        Label("common.cancel", systemImage: "xmark")
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(action: onSave) {
                        Label("common.save", systemImage: "checkmark")
                    }
                    .disabled(draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func parentOptionTitle(for item: DraftCategoryHierarchyItem) -> String {
        String(repeating: "  ", count: max(item.depth - 1, 0)) + draftStore.categoryDisplayName(for: item.category.id)
    }
}

#Preview {
    NavigationStack {
        CategoryManagementPage()
            .environmentObject(DraftBookkeepingStore())
    }
}
