import SwiftUI

struct CategoryManagementPage: View {
    @EnvironmentObject private var draftStore: DraftBookkeepingStore
    @State private var selectedKind = DraftEntryKind.expense
    @State private var editingCategory: DraftCategory?
    @State private var draft = CategoryEditorDraft.empty
    @State private var isEditorPresented = false

    var body: some View {
        Form {
            Section {
                Picker("management.category.kind", selection: $selectedKind) {
                    Text("record.kind.expense").tag(DraftEntryKind.expense)
                    Text("record.kind.income").tag(DraftEntryKind.income)
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

                        Text(category.name)

                        Spacer()

                        Button {
                            beginEditing(category)
                        } label: {
                            Image(systemName: "pencil")
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel(Text("management.action.edit"))

                        Button(role: .destructive) {
                            _ = draftStore.deleteCategory(id: category.id)
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel(Text("management.action.delete"))
                    }
                    .padding(.vertical, 4)
                }
            } header: {
                Text("management.category.section")
            } footer: {
                Text("management.category.footer")
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

#Preview {
    NavigationStack {
        CategoryManagementPage()
            .environmentObject(DraftBookkeepingStore())
    }
}
