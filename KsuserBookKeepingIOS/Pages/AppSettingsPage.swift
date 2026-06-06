import SwiftUI

struct AppSettingsPage: View {
    @EnvironmentObject private var appLock: AppLockManager
    @EnvironmentObject private var profileStore: ProfileStore
    @EnvironmentObject private var draftStore: DraftBookkeepingStore
    @EnvironmentObject private var syncSettingsStore: SyncSettingsStore
    @EnvironmentObject private var syncCoordinator: SyncCoordinator
    @AppStorage("app.language") private var language = AppLanguage.system.rawValue
    @AppStorage("app.theme") private var theme = AppTheme.system.rawValue
    @AppStorage(WidgetSharedConfiguration.liveActivitiesEnabledKey) private var liveActivitiesEnabled = false
    @AppStorage(WidgetSharedConfiguration.budgetLiveActivitiesEnabledKey) private var budgetLiveActivitiesEnabled = true
    @AppStorage(WidgetSharedConfiguration.selectedBudgetLiveActivityIdKey) private var selectedBudgetLiveActivityId = ""
    @AppStorage(WidgetSharedConfiguration.liveActivityDisplayDurationKey) private var liveActivityDisplayDuration = LiveActivityDisplayDuration.tenSeconds.rawValue
    @State private var passwordSheetMode = PasswordSheetMode.setup
    @State private var isPasswordSheetPresented = false
    @State private var isShowingResetWarning = false
    @State private var isResetConfirmationPresented = false
    @State private var resetConfirmationText = ""
    @State private var resetMessageKey: String?
    @State private var isResettingData = false

    private var selectableBudgetUsages: [DraftBudgetUsage] {
        draftStore.budgetUsages()
    }

    private var dataResetWarningMessageKey: LocalizedStringKey {
        syncSettingsStore.configuration.backupEnabled
            ? "settings.dataReset.warning.message.syncEnabled"
            : "settings.dataReset.warning.message.localOnly"
    }

    var body: some View {
        Form {
            Section {
                Picker("settings.language", selection: $language) {
                    ForEach(AppLanguage.allCases) { option in
                        Text(option.titleKey).tag(option.rawValue)
                    }
                }
            } footer: {
                Text("settings.language.footer")
            }

            Section {
                Picker("settings.theme", selection: $theme) {
                    ForEach(AppTheme.allCases) { option in
                        Text(option.titleKey).tag(option.rawValue)
                    }
                }
            } footer: {
                Text("settings.theme.footer")
            }

            Section {
                Toggle("settings.liveActivities.enabled", isOn: Binding(
                    get: { liveActivitiesEnabled },
                    set: { enabled in
                        liveActivitiesEnabled = enabled
                        RecentTransactionLiveActivityManager.setFeatureEnabled(enabled)
                        if enabled {
                            budgetLiveActivitiesEnabled = false
                        }
                    }
                ))

                Toggle("settings.liveActivities.budget.enabled", isOn: Binding(
                    get: { budgetLiveActivitiesEnabled },
                    set: { enabled in
                        let resolvedEnabled = enabled && !selectableBudgetUsages.isEmpty
                        budgetLiveActivitiesEnabled = resolvedEnabled
                        RecentTransactionLiveActivityManager.setBudgetFeatureEnabled(resolvedEnabled)
                        if resolvedEnabled {
                            liveActivitiesEnabled = false
                            ensureSelectedBudget()
                        }
                    }
                ))
                .disabled(selectableBudgetUsages.isEmpty)

                if !selectableBudgetUsages.isEmpty {
                    Picker("settings.liveActivities.budget.selection", selection: $selectedBudgetLiveActivityId) {
                        ForEach(selectableBudgetUsages) { usage in
                            Text(draftStore.budgetDisplayName(usage.budget)).tag(usage.budget.id)
                        }
                    }
                    .disabled(!budgetLiveActivitiesEnabled)
                    .onChange(of: selectedBudgetLiveActivityId) { _, newValue in
                        RecentTransactionLiveActivityManager.setSelectedBudgetId(newValue)
                    }
                }

                Picker("settings.liveActivities.duration", selection: $liveActivityDisplayDuration) {
                    ForEach(LiveActivityDisplayDuration.allCases) { option in
                        Text(option.titleKey).tag(option.rawValue)
                    }
                }
                .disabled(!liveActivitiesEnabled && !budgetLiveActivitiesEnabled)
            } header: {
                Text("settings.liveActivities.section")
            } footer: {
                Text("settings.liveActivities.footer")
            }

            Section {
                Toggle("settings.security.appLock", isOn: Binding(
                    get: { appLock.isPasswordEnabled },
                    set: { enabled in
                        if enabled {
                            passwordSheetMode = .setup
                            isPasswordSheetPresented = true
                        } else {
                            appLock.disablePasswordLock()
                        }
                    }
                ))

                if appLock.isPasswordEnabled {
                    Button("settings.security.changePassword") {
                        passwordSheetMode = .change
                        isPasswordSheetPresented = true
                    }

                    Toggle("settings.security.biometricUnlock", isOn: Binding(
                        get: { appLock.isBiometricUnlockEnabled },
                        set: { enabled in
                            if enabled {
                                appLock.enableBiometricUnlock(
                                    reason: NSLocalizedString("appLock.biometric.reason", comment: "")
                                )
                            } else {
                                appLock.disableBiometricUnlock()
                            }
                        }
                    ))
                    .disabled(!appLock.isBiometricAvailable)

                    if !appLock.isBiometricAvailable {
                        Text("settings.security.biometricUnavailable")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    if let messageKey = appLock.messageKey {
                        Text(LocalizedStringKey(messageKey))
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
            } header: {
                Text("settings.security.section")
            } footer: {
                Text("settings.security.footer")
            }

            DataResetSection(
                backupEnabled: syncSettingsStore.configuration.backupEnabled,
                isResetting: isResettingData,
                messageKey: resetMessageKey,
                onResetTapped: {
                    isShowingResetWarning = true
                }
            )
        }
        .navigationTitle(Text("settings.title"))
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .sheet(isPresented: $isPasswordSheetPresented) {
            PasswordSetupSheet(mode: passwordSheetMode, appLock: appLock)
        }
        .sheet(isPresented: $isResetConfirmationPresented) {
            DataResetConfirmationSheet(
                confirmationText: $resetConfirmationText,
                syncBackupEnabled: syncSettingsStore.configuration.backupEnabled,
                isResetting: isResettingData,
                onCancel: {
                    resetConfirmationText = ""
                    isResetConfirmationPresented = false
                },
                onConfirm: {
                    Task {
                        await resetAllData()
                    }
                }
            )
        }
        .onAppear {
            ensureSelectedBudget()
        }
        .onChange(of: draftStore.budgets) { _, _ in
            ensureSelectedBudget()
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                AppBackButton()
            }
        }
        .alert(Text("settings.dataReset.warning.title"), isPresented: $isShowingResetWarning) {
            Button("common.cancel", role: .cancel) {}
            Button("settings.dataReset.warning.continue", role: .destructive) {
                resetConfirmationText = ""
                isResetConfirmationPresented = true
            }
        } message: {
            Text(dataResetWarningMessageKey)
        }
    }

    private func ensureSelectedBudget() {
        let budgetIds = selectableBudgetUsages.map(\.budget.id)
        if selectedBudgetLiveActivityId.isEmpty || !budgetIds.contains(selectedBudgetLiveActivityId) {
            selectedBudgetLiveActivityId = budgetIds.first ?? ""
            RecentTransactionLiveActivityManager.setSelectedBudgetId(selectedBudgetLiveActivityId)
        }

        if budgetLiveActivitiesEnabled, selectedBudgetLiveActivityId.isEmpty {
            budgetLiveActivitiesEnabled = false
            RecentTransactionLiveActivityManager.setBudgetFeatureEnabled(false)
        }
    }

    private func resetAllData() async {
        let normalizedConfirmation = resetConfirmationText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard DataResetConfirmationPhrase.isValid(normalizedConfirmation) else {
            resetMessageKey = "settings.dataReset.error.confirmationMismatch"
            return
        }

        let configuration = syncSettingsStore.configuration
        let secrets = syncSettingsStore.secrets(for: configuration)
        isResettingData = true
        resetMessageKey = nil

        if configuration.backupEnabled {
            let didClearRemote = await syncCoordinator.clearRemoteBackupData(
                configuration: configuration,
                secrets: secrets
            )
            guard didClearRemote else {
                isResettingData = false
                resetMessageKey = "settings.dataReset.error.remoteFailed"
                return
            }
        }

        syncCoordinator.suspendBackupSchedulingForLocalReset()
        defer {
            syncCoordinator.resumeBackupSchedulingAfterLocalReset()
            isResettingData = false
        }

        do {
            try profileStore.resetLocalProfile()
            try draftStore.resetAllLocalData()
            resetConfirmationText = ""
            isResetConfirmationPresented = false
            resetMessageKey = "settings.dataReset.completed"
        } catch {
            resetMessageKey = "settings.dataReset.error.localFailed"
        }
    }
}

private enum LiveActivityDisplayDuration: Int, CaseIterable, Identifiable {
    case fiveSeconds = 5
    case tenSeconds = 10
    case thirtySeconds = 30
    case oneMinute = 60

    var id: Int { rawValue }

    var titleKey: LocalizedStringKey {
        switch self {
        case .fiveSeconds:
            return "settings.liveActivities.duration.5s"
        case .tenSeconds:
            return "settings.liveActivities.duration.10s"
        case .thirtySeconds:
            return "settings.liveActivities.duration.30s"
        case .oneMinute:
            return "settings.liveActivities.duration.1m"
        }
    }
}

private enum PasswordSheetMode {
    case setup
    case change

    var titleKey: LocalizedStringKey {
        switch self {
        case .setup:
            return "settings.security.password.setup.title"
        case .change:
            return "settings.security.password.change.title"
        }
    }
}

private struct DataResetSection: View {
    let backupEnabled: Bool
    let isResetting: Bool
    let messageKey: String?
    let onResetTapped: () -> Void

    private var footerKey: LocalizedStringKey {
        backupEnabled
            ? "settings.dataReset.footer.syncEnabled"
            : "settings.dataReset.footer.localOnly"
    }

    private var messageColor: Color {
        messageKey == "settings.dataReset.completed" ? .secondary : .red
    }

    var body: some View {
        Section {
            Button(role: .destructive) {
                onResetTapped()
            } label: {
                Label("settings.dataReset.action", systemImage: "trash")
            }
            .disabled(isResetting)

            if let messageKey {
                Text(LocalizedStringKey(messageKey))
                    .font(.footnote)
                    .foregroundStyle(messageColor)
            }
        } header: {
            Text("settings.data.section")
        } footer: {
            Text(footerKey)
        }
    }
}

private struct PasswordSetupSheet: View {
    let mode: PasswordSheetMode
    @ObservedObject var appLock: AppLockManager

    @Environment(\.dismiss) private var dismiss
    @State private var password = ""
    @State private var confirmation = ""
    @State private var errorKey: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("settings.security.password.placeholder", text: $password)
                        .textContentType(.newPassword)

                    SecureField("settings.security.password.confirm.placeholder", text: $confirmation)
                        .textContentType(.newPassword)
                } footer: {
                    Text("settings.security.password.requirement")
                }

                if let errorKey {
                    Text(LocalizedStringKey(errorKey))
                        .foregroundStyle(.red)
                }
            }
            .navigationTitle(Text(mode.titleKey))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("common.save") {
                        savePassword()
                    }
                    .disabled(password.isEmpty || confirmation.isEmpty)
                }
            }
        }
    }

    private func savePassword() {
        guard password.count >= 4 else {
            errorKey = "settings.security.error.passwordTooShort"
            return
        }

        guard password == confirmation else {
            errorKey = "settings.security.error.passwordMismatch"
            return
        }

        do {
            try appLock.savePassword(password)
            dismiss()
        } catch {
            errorKey = "settings.security.error.saveFailed"
        }
    }
}

private enum DataResetConfirmationPhrase {
    static let chinese = "我不想记账辣"
    static let english = "i do not want to keep bookkeeping anymore"

    static func isValid(_ text: String) -> Bool {
        text == chinese || text.localizedCaseInsensitiveCompare(english) == .orderedSame
    }
}

private struct DataResetConfirmationSheet: View {
    @Binding var confirmationText: String
    let syncBackupEnabled: Bool
    let isResetting: Bool
    let onCancel: () -> Void
    let onConfirm: () -> Void

    private var messageKey: LocalizedStringKey {
        syncBackupEnabled
            ? "settings.dataReset.confirm.message.syncEnabled"
            : "settings.dataReset.confirm.message.localOnly"
    }

    private var canConfirm: Bool {
        DataResetConfirmationPhrase.isValid(confirmationText.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(messageKey)
                        .foregroundStyle(.secondary)

                    TextField("settings.dataReset.confirm.placeholder", text: $confirmationText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } footer: {
                    Text("settings.dataReset.confirm.footer")
                }
            }
            .navigationTitle(Text("settings.dataReset.confirm.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") {
                        onCancel()
                    }
                    .disabled(isResetting)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(role: .destructive) {
                        onConfirm()
                    } label: {
                        if isResetting {
                            ProgressView()
                        } else {
                            Text("settings.dataReset.confirm.delete")
                        }
                    }
                    .disabled(isResetting || !canConfirm)
                }
            }
        }
    }
}
