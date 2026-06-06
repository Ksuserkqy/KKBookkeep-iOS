import SwiftUI

struct SyncSettingsPage: View {
    @EnvironmentObject private var profileStore: ProfileStore
    @EnvironmentObject private var draftBookkeepingStore: DraftBookkeepingStore
    @EnvironmentObject private var syncSettingsStore: SyncSettingsStore
    @EnvironmentObject private var syncCoordinator: SyncCoordinator

    @StateObject private var viewModel = SyncSettingsViewModel()

    var body: some View {
        Form {
            if let messageKey = viewModel.settingsMessageKey {
                Section {
                    Label {
                        Text(LocalizedStringKey(messageKey))
                    } icon: {
                        Image(systemName: viewModel.isErrorMessage(messageKey) ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
                    }
                    .foregroundStyle(viewModel.isErrorMessage(messageKey) ? .red : .green)
                }
            }

            Section {
                LabeledContent("sync.status") {
                    if viewModel.backupEnabled {
                        Text(viewModel.provider.titleKey)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("sync.status.localOnly")
                            .foregroundStyle(.secondary)
                    }
                }

                LabeledContent("sync.setupMode") {
                    Text(viewModel.setupModeTextKey)
                        .foregroundStyle(.secondary)
                }

                LabeledContent("sync.lastSync") {
                    Text(viewModel.lastBackupText)
                        .foregroundStyle(.secondary)
                }

                LabeledContent("sync.conflictHandling") {
                    Text("sync.conflictHandling.automatic")
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("sync.section.status")
            }

            Section {
                Toggle("sync.backupEnabled", isOn: $viewModel.backupEnabled)
                    .tint(.accentColor)

                Picker("sync.provider", selection: $viewModel.provider) {
                    ForEach(SyncProvider.allCases) { option in
                        Text(option.titleKey).tag(option)
                    }
                }
            } header: {
                Text("sync.section.provider")
            } footer: {
                if viewModel.provider == .iCloudDrive {
                    Text("sync.iCloud.footer")
                }
            }

            if viewModel.provider == .webDAV {
                Section {
                    TextField("sync.webDAV.server.placeholder", text: $viewModel.serverURL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    Picker("sync.webDAV.authentication", selection: $viewModel.webDAVAuthentication) {
                        ForEach(WebDAVAuthentication.allCases) { option in
                            Text(option.titleKey).tag(option)
                        }
                    }

                    if viewModel.webDAVAuthentication == .password {
                        TextField("sync.webDAV.username.placeholder", text: $viewModel.username)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()

                        SecureField("sync.webDAV.password.placeholder", text: $viewModel.password)
                    } else {
                        SecureField("sync.webDAV.token.placeholder", text: $viewModel.accessToken)
                    }
                } header: {
                    Text("sync.section.webDAV")
                } footer: {
                    Text("sync.webDAV.footer")
                }
            }

            Section {
                Toggle("sync.backupOnChange", isOn: $viewModel.backupOnChange)
                    .tint(.accentColor)
                Toggle("sync.autoImport", isOn: $viewModel.autoImport)
                    .tint(.accentColor)

                Picker("sync.backupInterval", selection: $viewModel.backupInterval) {
                    ForEach(BackupInterval.allCases) { option in
                        Text(option.titleKey).tag(option)
                    }
                }
            } header: {
                Text("sync.section.behavior")
            } footer: {
                Text("sync.behavior.footer")
            }

            Section {
                Toggle("sync.encryption.enabled", isOn: $viewModel.encryptionEnabled)
                    .tint(.accentColor)

                SecureField("sync.encryption.password.placeholder", text: $viewModel.encryptionPassword)

                SecureField("sync.encryption.confirm.placeholder", text: $viewModel.encryptionPasswordConfirmation)

                LabeledContent("sync.encryption.algorithm") {
                    Text("sync.encryption.algorithm.aesGCM")
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("sync.section.encryption")
            } footer: {
                Text("sync.encryption.footer")
            }

            Section {
                Button("sync.action.testConnection") {
                    Task {
                        await viewModel.testConnection()
                    }
                }
                .disabled(viewModel.isRunningSyncAction)

                Button("sync.action.backupNow") {
                    Task {
                        await viewModel.backupNow()
                    }
                }
                .disabled(viewModel.isRunningSyncAction)

                Button("sync.action.importNow") {
                    Task {
                        await viewModel.importNow()
                    }
                }
                .disabled(viewModel.isRunningSyncAction)

                Button("sync.action.runLocalOnly") {
                    viewModel.runLocalOnly()
                }
                .disabled(viewModel.isRunningSyncAction)
            } footer: {
                if let messageKey = viewModel.settingsMessageKey ?? profileStore.messageKey ?? draftBookkeepingStore.messageKey {
                    Text(LocalizedStringKey(messageKey))
                }
            }
        }
        .navigationTitle(Text("sync.title"))
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                AppBackButton()
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task {
                        await viewModel.saveSettings()
                    }
                } label: {
                    if viewModel.isSaving {
                        ProgressView()
                    } else {
                        Text("common.save")
                    }
                }
                .disabled(viewModel.isSaving)
            }
        }
        .task {
            viewModel.configure(
                syncSettingsStore: syncSettingsStore,
                syncCoordinator: syncCoordinator
            )
        }
        .alert(Text("sync.settings.message.title"), isPresented: $viewModel.isShowingSettingsMessage) {
            Button("common.ok", role: .cancel) {}
        } message: {
            if let messageKey = viewModel.settingsMessageKey {
                Text(LocalizedStringKey(messageKey))
            }
        }
        .alert(Text("sync.backup.confirmBeforeImport.title"), isPresented: $viewModel.isShowingBackupBeforeImportConfirmation) {
            Button("sync.backup.confirmBeforeImport.importFirst", role: .cancel) {
                viewModel.cancelBackupBeforeImport()
            }
            Button("sync.backup.confirmBeforeImport.continueBackup", role: .destructive) {
                Task {
                    await viewModel.confirmBackupBeforeImport()
                }
            }
        } message: {
            Text("sync.backup.confirmBeforeImport.message")
        }
    }
}
