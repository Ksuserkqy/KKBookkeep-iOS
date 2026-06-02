import SwiftUI

struct SyncSettingsPage: View {
    @EnvironmentObject private var profileStore: ProfileStore
    @EnvironmentObject private var draftBookkeepingStore: DraftBookkeepingStore
    @EnvironmentObject private var syncSettingsStore: SyncSettingsStore

    @State private var backupEnabled = false
    @State private var provider = SyncProvider.webDAV
    @State private var webDAVAuthentication = WebDAVAuthentication.password
    @State private var serverURL = ""
    @State private var username = ""
    @State private var password = ""
    @State private var accessToken = ""
    @State private var backupOnChange = true
    @State private var autoImport = true
    @State private var backupInterval = BackupInterval.tenMinutes
    @State private var encryptionEnabled = true
    @State private var encryptionPassword = ""
    @State private var encryptionPasswordConfirmation = ""
    @State private var isSaving = false
    @State private var isRunningSyncAction = false
    @State private var settingsMessageKey: String?
    @State private var isShowingSettingsMessage = false

    var body: some View {
        Form {
            if let messageKey = settingsMessageKey {
                Section {
                    Label {
                        Text(LocalizedStringKey(messageKey))
                    } icon: {
                        Image(systemName: isErrorMessage(messageKey) ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
                    }
                    .foregroundStyle(isErrorMessage(messageKey) ? .red : .green)
                }
            }

            Section {
                LabeledContent("sync.status") {
                    if backupEnabled {
                        Text(provider.titleKey)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("sync.status.localOnly")
                            .foregroundStyle(.secondary)
                    }
                }

                LabeledContent("sync.setupMode") {
                    Text(setupModeTextKey)
                        .foregroundStyle(.secondary)
                }

                LabeledContent("sync.lastSync") {
                    Text(lastBackupText)
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
                Toggle("sync.backupEnabled", isOn: $backupEnabled)
                    .tint(.accentColor)

                Picker("sync.provider", selection: $provider) {
                    ForEach(SyncProvider.allCases) { option in
                        Text(option.titleKey).tag(option)
                            .disabled(!option.isAvailable)
                    }
                }
            } header: {
                Text("sync.section.provider")
            } footer: {
                if provider == .iCloudDrive {
                    Text("sync.provider.iCloudDrive.unavailable")
                }
            }

            if provider == .webDAV {
                Section {
                    TextField("sync.webDAV.server.placeholder", text: $serverURL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    Picker("sync.webDAV.authentication", selection: $webDAVAuthentication) {
                        ForEach(WebDAVAuthentication.allCases) { option in
                            Text(option.titleKey).tag(option)
                        }
                    }

                    if webDAVAuthentication == .password {
                        TextField("sync.webDAV.username.placeholder", text: $username)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()

                        SecureField("sync.webDAV.password.placeholder", text: $password)
                    } else {
                        SecureField("sync.webDAV.token.placeholder", text: $accessToken)
                    }
                } header: {
                    Text("sync.section.webDAV")
                } footer: {
                    Text("sync.webDAV.footer")
                }
            }

            Section {
                Toggle("sync.backupOnChange", isOn: $backupOnChange)
                    .tint(.accentColor)
                Toggle("sync.autoImport", isOn: $autoImport)
                    .tint(.accentColor)

                Picker("sync.backupInterval", selection: $backupInterval) {
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
                Toggle("sync.encryption.enabled", isOn: $encryptionEnabled)
                    .tint(.accentColor)

                SecureField("sync.encryption.password.placeholder", text: $encryptionPassword)

                SecureField("sync.encryption.confirm.placeholder", text: $encryptionPasswordConfirmation)

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
                        await testConnection()
                    }
                }
                .disabled(isRunningSyncAction)

                Button("sync.action.backupNow") {
                    Task {
                        await backupProfileNow()
                    }
                }
                .disabled(isRunningSyncAction)

                Button("sync.action.importNow") {
                    Task {
                        await importProfileNow()
                    }
                }
                .disabled(isRunningSyncAction)

                Button("sync.action.runLocalOnly") {
                    runLocalOnly()
                }
                .disabled(isRunningSyncAction)
            } footer: {
                if let messageKey = settingsMessageKey ?? profileStore.messageKey ?? draftBookkeepingStore.messageKey {
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
                        await saveSettings()
                    }
                } label: {
                    if isSaving {
                        ProgressView()
                    } else {
                        Text("common.save")
                    }
                }
                .disabled(isSaving)
            }
        }
        .task {
            loadSettings()
        }
        .alert(Text("sync.settings.message.title"), isPresented: $isShowingSettingsMessage) {
            Button("common.ok", role: .cancel) {}
        } message: {
            if let messageKey = settingsMessageKey {
                Text(LocalizedStringKey(messageKey))
            }
        }
    }

    private func loadSettings() {
        let draft = syncSettingsStore.makeDraft()
        backupEnabled = draft.configuration.backupEnabled
        provider = draft.configuration.provider
        webDAVAuthentication = draft.configuration.webDAVAuthentication
        serverURL = draft.configuration.webDAVServerURL
        username = draft.configuration.webDAVUsername
        password = draft.password
        accessToken = draft.accessToken
        backupOnChange = draft.configuration.backupOnChange
        autoImport = draft.configuration.autoImport
        backupInterval = draft.configuration.backupInterval
        encryptionEnabled = draft.configuration.encryptionEnabled
        encryptionPassword = draft.encryptionPassword
        encryptionPasswordConfirmation = draft.encryptionPassword
    }

    private func saveSettings() async {
        if backupEnabled, provider == .iCloudDrive {
            showSettingsMessage("sync.settings.error.providerUnavailable")
            return
        }

        if backupEnabled, encryptionEnabled, encryptionPassword.isEmpty {
            showSettingsMessage("sync.settings.error.encryptionPasswordRequired")
            return
        }

        if backupEnabled, encryptionEnabled, encryptionPassword != encryptionPasswordConfirmation {
            showSettingsMessage("sync.settings.error.encryptionPasswordMismatch")
            return
        }

        isSaving = true

        let configuration = makeConfiguration()
        let draft = SyncSettingsDraft(
            configuration: configuration,
            password: password,
            accessToken: accessToken,
            encryptionPassword: encryptionEnabled ? encryptionPassword : ""
        )

        do {
            try syncSettingsStore.save(draft)

            if configuration.backupEnabled {
                syncSettingsStore.completeInitialSetup(.syncSpace)
                let secrets = currentSyncSecrets()
                let profileBackedUp = await profileStore.backupNow(configuration: configuration, secrets: secrets)
                let ledgerDataBackedUp = await draftBookkeepingStore.backupLedgerDataNow(
                    configuration: configuration,
                    secrets: secrets,
                    forceFullUpload: true
                )

                if profileBackedUp, ledgerDataBackedUp {
                    try? syncSettingsStore.markBackupCompleted()
                    showSettingsMessage("sync.settings.savedAndBackedUp")
                } else {
                    showSettingsMessage("sync.settings.savedButBackupFailed")
                }
            } else {
                syncSettingsStore.completeInitialSetup(.localOnly)
                showSettingsMessage("sync.settings.saved")
            }
        } catch {
            showSettingsMessage("sync.settings.error.saveFailed")
        }

        isSaving = false
    }

    private func testConnection() async {
        await runSyncAction {
            await profileStore.testSyncLocation(
                configuration: savedOrCurrentConfiguration(),
                secrets: currentSyncSecrets()
            )
        }
    }

    private func backupProfileNow() async {
        await runSyncAction {
            let configuration = savedOrCurrentConfiguration()
            let secrets = currentSyncSecrets()
            let profileBackedUp = await profileStore.backupNow(configuration: configuration, secrets: secrets)
            let ledgerDataBackedUp = await draftBookkeepingStore.backupLedgerDataNow(
                configuration: configuration,
                secrets: secrets,
                forceFullUpload: true
            )

            if profileBackedUp, ledgerDataBackedUp {
                try? syncSettingsStore.markBackupCompleted()
                showSettingsMessage("sync.backup.succeeded")
            } else {
                showSettingsMessage("sync.backup.error.failed")
            }
        }
    }

    private func importProfileNow() async {
        await runSyncAction {
            let configuration = savedOrCurrentConfiguration()
            let secrets = currentSyncSecrets()
            let profileImported = await profileStore.importNow(configuration: configuration, secrets: secrets)
            let metadataImported = await draftBookkeepingStore.importMetadataNow(
                configuration: configuration,
                secrets: secrets
            )
            let transactionsImported = await draftBookkeepingStore.importTransactionsNow(
                configuration: configuration,
                secrets: secrets
            )
            let templatesImported = await draftBookkeepingStore.importTemplatesNow(
                configuration: configuration,
                secrets: secrets
            )
            if profileImported, metadataImported, transactionsImported, templatesImported {
                do {
                    try syncSettingsStore.save(
                        SyncSettingsDraft(
                            configuration: configuration,
                            password: password,
                            accessToken: accessToken,
                            encryptionPassword: encryptionEnabled ? encryptionPassword : ""
                        )
                    )
                } catch {
                    showSettingsMessage("sync.settings.error.saveFailed")
                    return
                }
                syncSettingsStore.completeInitialSetup(.syncSpace)
            }
            showSettingsMessage(profileImported && metadataImported && transactionsImported && templatesImported ? "sync.import.completed" : "sync.import.error.failed")
        }
    }

    private func runLocalOnly() {
        isRunningSyncAction = true
        backupEnabled = false
        autoImport = false
        backupOnChange = false

        var configuration = makeConfiguration()
        configuration.backupEnabled = false
        configuration.autoImport = false
        configuration.backupOnChange = false

        let draft = SyncSettingsDraft(
            configuration: configuration,
            password: password,
            accessToken: accessToken,
            encryptionPassword: encryptionEnabled ? encryptionPassword : ""
        )

        do {
            try syncSettingsStore.save(draft)
            syncSettingsStore.completeInitialSetup(.localOnly)
            showSettingsMessage("sync.settings.localOnlySaved")
        } catch {
            showSettingsMessage("sync.settings.error.saveFailed")
        }

        isRunningSyncAction = false
    }

    private func runSyncAction(_ action: @escaping () async -> Void) async {
        settingsMessageKey = nil
        isRunningSyncAction = true
        await action()
        isRunningSyncAction = false
    }

    private func savedOrCurrentConfiguration() -> SyncConfiguration {
        let current = makeConfiguration()
        if current == syncSettingsStore.configuration {
            return syncSettingsStore.configuration
        }

        return current
    }

    private func makeConfiguration() -> SyncConfiguration {
        SyncConfiguration(
            backupEnabled: backupEnabled,
            provider: provider,
            webDAVAuthentication: webDAVAuthentication,
            webDAVServerURL: serverURL.trimmingCharacters(in: .whitespacesAndNewlines),
            webDAVUsername: username.trimmingCharacters(in: .whitespacesAndNewlines),
            backupOnChange: backupOnChange,
            autoImport: autoImport,
            backupInterval: backupInterval,
            encryptionEnabled: encryptionEnabled,
            lastBackupAt: syncSettingsStore.configuration.lastBackupAt
        )
    }

    private func currentSyncSecrets() -> SyncSecrets {
        SyncSecrets(
            webDAVSecret: currentWebDAVSecret(),
            encryptionPassword: encryptionPassword
        )
    }

    private func currentWebDAVSecret() -> String {
        switch webDAVAuthentication {
        case .password:
            return password
        case .token:
            return accessToken
        }
    }

    private func showSettingsMessage(_ key: String) {
        settingsMessageKey = key
        isShowingSettingsMessage = true
    }

    private func isErrorMessage(_ key: String) -> Bool {
        key.contains(".error.")
    }

    private var lastBackupText: String {
        guard let lastBackupAt = syncSettingsStore.configuration.lastBackupAt else {
            return String(localized: "sync.lastSync.never")
        }

        return lastBackupAt.formatted(
            date: .abbreviated,
            time: .shortened
        )
    }

    private var setupModeTextKey: LocalizedStringKey {
        switch syncSettingsStore.setupChoice {
        case .undecided:
            return "sync.setupMode.undecided"
        case .syncSpace:
            return "sync.setupMode.syncSpace"
        case .localOnly:
            return "sync.setupMode.localOnly"
        }
    }
}
