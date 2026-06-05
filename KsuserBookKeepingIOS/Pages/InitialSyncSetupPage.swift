import SwiftUI

struct InitialSyncSetupPage: View {
    @EnvironmentObject private var profileStore: ProfileStore
    @EnvironmentObject private var draftBookkeepingStore: DraftBookkeepingStore
    @EnvironmentObject private var syncSettingsStore: SyncSettingsStore

    let onComplete: () -> Void

    @State private var currentStep = InitialSetupStep.legal
    @State private var didLoadExistingDraft = false
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
    @State private var safariPage: SafariPage?

    private let userAgreementURL = URL(string: "https://www.ksuser.cn/agreement/user.html")!
    private let privacyPolicyURL = URL(string: "https://www.ksuser.cn/agreement/privacy.html")!

    var body: some View {
        NavigationStack {
            Group {
                switch currentStep {
                case .legal:
                    legalConsentView
                case .syncChoice:
                    syncChoiceView
                case .webDAVConfiguration:
                    webDAVConfigurationView
                }
            }
            .navigationTitle(Text(currentStep.navigationTitleKey))
            .navigationBarTitleDisplayMode(currentStep.titleDisplayMode)
            .tint(.accentColor)
            .toolbar {
                if currentStep == .webDAVConfiguration {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("common.back") {
                            currentStep = .syncChoice
                        }
                        .disabled(isWorking)
                    }
                }
            }
        }
        .interactiveDismissDisabled()
        .sheet(item: $safariPage) { page in
            SafariView(url: page.url)
        }
        .task {
            guard !didLoadExistingDraft else { return }
            didLoadExistingDraft = true
            loadExistingDraft()
            currentStep = syncSettingsStore.hasAcceptedLegalTerms ? .syncChoice : .legal
        }
        .alert(Text("sync.settings.message.title"), isPresented: $isShowingMessage) {
            Button("common.ok", role: .cancel) {}
        } message: {
            if let messageKey {
                Text(LocalizedStringKey(messageKey))
            }
        }
    }

    private var legalConsentView: some View {
        Form {
            Section {
                VStack(alignment: .center, spacing: 16) {
                    AppIconView(cornerRadius: 18)
                        .frame(width: 76, height: 76)

                    VStack(spacing: 8) {
                        Text("initialSync.legal.title")
                            .font(.title3.weight(.semibold))
                            .multilineTextAlignment(.center)

                        Text("initialSync.legal.subtitle")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
            }

            Section {
                Button {
                    safariPage = SafariPage(url: userAgreementURL)
                } label: {
                    Label("initialSync.legal.terms", systemImage: "doc.plaintext")
                }
                .foregroundStyle(.primary)

                Button {
                    safariPage = SafariPage(url: privacyPolicyURL)
                } label: {
                    Label("initialSync.legal.privacy", systemImage: "lock.shield")
                }
                .foregroundStyle(.primary)
            } footer: {
                Text("initialSync.legal.footer")
            }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                Button {
                    acceptLegalTerms()
                } label: {
                    Text("initialSync.legal.accept")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(.accentColor)
                .disabled(isWorking)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 8)
            .background(.bar)
        }
    }

    private var syncChoiceView: some View {
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

            messageSection

            Section {
                syncChoiceButton(
                    titleKey: "initialSync.choice.iCloud.title",
                    subtitleKey: "initialSync.choice.iCloud.subtitle",
                    systemImage: "icloud.fill",
                    isAvailable: false
                ) {}

                syncChoiceButton(
                    titleKey: "initialSync.choice.webDAV.title",
                    subtitleKey: "initialSync.choice.webDAV.subtitle",
                    systemImage: "server.rack"
                ) {
                    provider = .webDAV
                    currentStep = .webDAVConfiguration
                }

                syncChoiceButton(
                    titleKey: "initialSync.choice.localOnly.title",
                    subtitleKey: "initialSync.choice.localOnly.subtitle",
                    systemImage: "iphone"
                ) {
                    runLocalOnly()
                }
            } header: {
                Text("initialSync.choice.section")
            } footer: {
                Text("initialSync.choice.footer")
            }
        }
    }

    private var webDAVConfigurationView: some View {
        Form {
            messageSection

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

            Section {
                Toggle("sync.autoImport", isOn: $autoImport)
                    .tint(.accentColor)
                Toggle("sync.backupOnChange", isOn: $backupOnChange)
                    .tint(.accentColor)
            } header: {
                Text("sync.section.behavior")
            } footer: {
                Text("initialSync.behavior.footer")
            }

            Section {
                Toggle("sync.encryption.enabled", isOn: $encryptionEnabled)
                    .tint(.accentColor)

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
                    setupActionLabel(
                        titleKey: "initialSync.action.import",
                        systemImage: "square.and.arrow.down"
                    )
                }
                .disabled(isWorking)
            } footer: {
                Text("initialSync.actions.footer")
            }
        }
    }

    @ViewBuilder
    private var messageSection: some View {
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
    }

    private func syncChoiceButton(
        titleKey: String,
        subtitleKey: String,
        systemImage: String,
        isAvailable: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            action()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.title3)
                    .foregroundStyle(isAvailable ? Color.accentColor : Color.secondary)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(LocalizedStringKey(titleKey))
                            .font(.body)
                            .foregroundStyle(.primary)

                        if !isAvailable {
                            Text("initialSync.choice.unavailable")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                    }

                    Text(LocalizedStringKey(subtitleKey))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 8)

                if isAvailable {
                    if isWorking {
                        ProgressView()
                    } else {
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
            .opacity(isAvailable ? 1 : 0.55)
        }
        .buttonStyle(.plain)
        .disabled(!isAvailable || isWorking)
    }

    private func setupActionLabel(titleKey: String, systemImage: String) -> some View {
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

    private func acceptLegalTerms() {
        syncSettingsStore.acceptLegalTerms()

        if syncSettingsStore.setupChoice == .undecided {
            currentStep = .syncChoice
        } else {
            onComplete()
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
        let templatesImported = await draftBookkeepingStore.importTemplatesNow(
            configuration: configuration,
            secrets: secrets
        )
        let budgetsImported = await draftBookkeepingStore.importBudgetsNow(
            configuration: configuration,
            secrets: secrets
        )

        if profileImported, metadataImported, transactionsImported, templatesImported, budgetsImported {
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

private enum InitialSetupStep {
    case legal
    case syncChoice
    case webDAVConfiguration

    var navigationTitleKey: LocalizedStringKey {
        switch self {
        case .legal:
            return "initialSync.legal.navigationTitle"
        case .syncChoice:
            return "initialSync.navigationTitle"
        case .webDAVConfiguration:
            return "initialSync.webDAV.navigationTitle"
        }
    }

    var titleDisplayMode: NavigationBarItem.TitleDisplayMode {
        switch self {
        case .legal:
            return .large
        case .syncChoice, .webDAVConfiguration:
            return .inline
        }
    }
}
