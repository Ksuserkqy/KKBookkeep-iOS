import SwiftUI

struct InitialSyncSetupPage: View {
    @EnvironmentObject private var profileStore: ProfileStore
    @EnvironmentObject private var draftBookkeepingStore: DraftBookkeepingStore
    @EnvironmentObject private var syncSettingsStore: SyncSettingsStore

    let onComplete: () -> Void

    @State private var provider = SyncProvider.webDAV
    @State private var webDAVAuthentication = WebDAVAuthentication.password
    @State private var serverURL = ""
    @State private var username = ""
    @State private var password = ""
    @State private var accessToken = ""
    @State private var autoImport = true
    @State private var backupOnChange = true
    @State private var encryptionEnabled = true
    @State private var encryptionPassword = ""
    @State private var encryptionPasswordConfirmation = ""
    @State private var isWorking = false
    @State private var messageKey: String?
    @State private var isShowingMessage = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("initialSync.title", systemImage: "arrow.triangle.2.circlepath.circle.fill")
                            .font(.headline)

                        Text("initialSync.subtitle")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 6)
                }

                if let messageKey {
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
                    } else {
                        Text("initialSync.provider.footer")
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
                    Toggle("sync.autoImport", isOn: $autoImport)
                    Toggle("sync.backupOnChange", isOn: $backupOnChange)
                } header: {
                    Text("sync.section.behavior")
                } footer: {
                    Text("initialSync.behavior.footer")
                }

                Section {
                    Toggle("sync.encryption.enabled", isOn: $encryptionEnabled)

                    SecureField("sync.encryption.password.placeholder", text: $encryptionPassword)

                    SecureField("sync.encryption.confirm.placeholder", text: $encryptionPasswordConfirmation)
                } header: {
                    Text("sync.section.encryption")
                } footer: {
                    Text("sync.encryption.footer")
                }

                Section {
                    Button {
                        Task {
                            await importFromSyncSpace()
                        }
                    } label: {
                        syncActionLabel(
                            titleKey: "initialSync.action.import",
                            systemImage: "square.and.arrow.down"
                        )
                    }
                    .disabled(isWorking)

                    Button {
                        runLocalOnly()
                    } label: {
                        syncActionLabel(
                            titleKey: "initialSync.action.localOnly",
                            systemImage: "iphone"
                        )
                    }
                    .disabled(isWorking)
                } footer: {
                    Text("initialSync.actions.footer")
                }
            }
            .navigationTitle(Text("initialSync.navigationTitle"))
            .navigationBarTitleDisplayMode(.inline)
        }
        .interactiveDismissDisabled()
        .task {
            loadExistingDraft()
        }
        .alert(Text("sync.settings.message.title"), isPresented: $isShowingMessage) {
            Button("common.ok", role: .cancel) {}
        } message: {
            if let messageKey {
                Text(LocalizedStringKey(messageKey))
            }
        }
    }

    private func syncActionLabel(titleKey: String, systemImage: String) -> some View {
        HStack {
            Label {
                Text(LocalizedStringKey(titleKey))
            } icon: {
                Image(systemName: systemImage)
            }
            Spacer()
            if isWorking {
                ProgressView()
            }
        }
    }

    private func loadExistingDraft() {
        let draft = syncSettingsStore.makeDraft()
        provider = draft.configuration.provider
        webDAVAuthentication = draft.configuration.webDAVAuthentication
        serverURL = draft.configuration.webDAVServerURL
        username = draft.configuration.webDAVUsername
        password = draft.password
        accessToken = draft.accessToken
        autoImport = draft.configuration.autoImport
        backupOnChange = draft.configuration.backupOnChange
        encryptionEnabled = draft.configuration.encryptionEnabled
        encryptionPassword = draft.encryptionPassword
        encryptionPasswordConfirmation = draft.encryptionPassword
    }

    private func importFromSyncSpace() async {
        guard validateSyncSpaceSettings() else { return }

        isWorking = true
        messageKey = nil

        let configuration = makeSyncSpaceConfiguration()
        let secrets = makeSyncSecrets()
        let profileImported = await profileStore.importNow(configuration: configuration, secrets: secrets)
        let metadataImported = await draftBookkeepingStore.importMetadataNow(
            configuration: configuration,
            secrets: secrets
        )
        let transactionsImported = await draftBookkeepingStore.importTransactionsNow(
            configuration: configuration,
            secrets: secrets
        )

        if profileImported, metadataImported, transactionsImported {
            let draft = SyncSettingsDraft(
                configuration: configuration,
                password: password,
                accessToken: accessToken,
                encryptionPassword: encryptionEnabled ? encryptionPassword : ""
            )

            do {
                try syncSettingsStore.save(draft)
                syncSettingsStore.completeInitialSetup(.syncSpace)
                showMessage("initialSync.import.completed")
                onComplete()
            } catch {
                showMessage("sync.settings.error.saveFailed")
            }
        } else {
            showMessage("sync.import.error.failed")
        }

        isWorking = false
    }

    private func runLocalOnly() {
        isWorking = true
        messageKey = nil

        var configuration = syncSettingsStore.configuration
        configuration.backupEnabled = false
        configuration.autoImport = false
        configuration.backupOnChange = false

        do {
            try syncSettingsStore.save(
                SyncSettingsDraft(
                    configuration: configuration,
                    password: password,
                    accessToken: accessToken,
                    encryptionPassword: encryptionPassword
                )
            )
            syncSettingsStore.completeInitialSetup(.localOnly)
            onComplete()
        } catch {
            showMessage("sync.settings.error.saveFailed")
        }

        isWorking = false
    }

    private func validateSyncSpaceSettings() -> Bool {
        if provider == .iCloudDrive {
            showMessage("sync.settings.error.providerUnavailable")
            return false
        }

        if encryptionEnabled, encryptionPassword.isEmpty {
            showMessage("sync.settings.error.encryptionPasswordRequired")
            return false
        }

        if encryptionEnabled, encryptionPassword != encryptionPasswordConfirmation {
            showMessage("sync.settings.error.encryptionPasswordMismatch")
            return false
        }

        return true
    }

    private func makeSyncSpaceConfiguration() -> SyncConfiguration {
        SyncConfiguration(
            backupEnabled: true,
            provider: provider,
            webDAVAuthentication: webDAVAuthentication,
            webDAVServerURL: serverURL.trimmingCharacters(in: .whitespacesAndNewlines),
            webDAVUsername: username.trimmingCharacters(in: .whitespacesAndNewlines),
            backupOnChange: backupOnChange,
            autoImport: autoImport,
            backupInterval: .tenMinutes,
            encryptionEnabled: encryptionEnabled,
            lastBackupAt: syncSettingsStore.configuration.lastBackupAt
        )
    }

    private func makeSyncSecrets() -> SyncSecrets {
        SyncSecrets(
            webDAVSecret: currentWebDAVSecret(),
            encryptionPassword: encryptionEnabled ? encryptionPassword : ""
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

    private func showMessage(_ key: String) {
        messageKey = key
        isShowingMessage = true
    }

    private func isErrorMessage(_ key: String) -> Bool {
        key.contains(".error.")
    }
}
