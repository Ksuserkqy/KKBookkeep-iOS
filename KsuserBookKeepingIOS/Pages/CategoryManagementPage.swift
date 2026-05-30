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

            if let messageKey = draftStore.messageKey {
                Section {
                    Text(LocalizedStringKey(messageKey))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                ForEach(draftStore.categories(for: selectedKind)) { category in
                    HStack(spacing: 12) {
                        DraftVisualBadge(iconName: category.iconName, colorHex: category.colorHex)

                        HStack(spacing: 6) {
                            Text(category.name)

                            if category.isDefault {
                                Text("management.defaultBadge")
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

                        if !category.isDefault {
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

            Section {
                Button {
                    beginAdding()
                } label: {
                    Label("management.category.add", systemImage: "plus.circle.fill")
                }
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
            Text("management.category.delete.confirm.message")
        }
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
            draftStore.updateCategory(
                id: editingCategory.id,
                name: draft.name,
                iconName: draft.iconName,
                colorHex: draft.colorHex
            )
        } else {
            draftStore.addCategory(
                name: draft.name,
                kind: selectedKind,
                iconName: draft.iconName,
                colorHex: draft.colorHex
            )
        }

        isEditorPresented = false
    }

    private func deletePendingCategory() {
        guard let deletingCategory else {
            return
        }

        _ = draftStore.deleteCategory(id: deletingCategory.id)
        self.deletingCategory = nil
    }
}

private struct CategoryEditorDraft {
    var name: String
    var iconName: String
    var colorHex: String

    static let empty = CategoryEditorDraft(
        name: "",
        iconName: DraftCustomizationOptions.categoryIcons[0],
        colorHex: DraftCustomizationOptions.colors[0]
    )

    init(name: String, iconName: String, colorHex: String) {
        self.name = name
        self.iconName = iconName
        self.colorHex = colorHex
    }

    init(category: DraftCategory) {
        self.name = category.name
        self.iconName = category.iconName
        self.colorHex = category.colorHex
    }
}

private struct CategoryEditorSheet: View {
    let isEditing: Bool
    let kind: DraftEntryKind
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
}

#Preview {
    NavigationStack {
        CategoryManagementPage()
            .environmentObject(DraftBookkeepingStore())
    }
}
