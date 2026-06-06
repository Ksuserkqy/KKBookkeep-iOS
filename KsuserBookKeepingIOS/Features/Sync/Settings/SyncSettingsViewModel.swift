import Foundation
import Combine
import SwiftUI

@MainActor
final class SyncSettingsViewModel: ObservableObject {
    @Published var backupEnabled = false
    @Published var provider = SyncProvider.webDAV
    @Published var webDAVAuthentication = WebDAVAuthentication.password
    @Published var serverURL = ""
    @Published var username = ""
    @Published var password = ""
    @Published var accessToken = ""
    @Published var backupOnChange = true
    @Published var autoImport = true
    @Published var backupInterval = BackupInterval.tenMinutes
    @Published var encryptionEnabled = true
    @Published var encryptionPassword = ""
    @Published var encryptionPasswordConfirmation = ""
    @Published var isSaving = false
    @Published var isRunningSyncAction = false
    @Published var settingsMessageKey: String?
    @Published var isShowingSettingsMessage = false

    private weak var syncSettingsStore: SyncSettingsStore?
    private weak var syncCoordinator: SyncCoordinator?

    func configure(syncSettingsStore: SyncSettingsStore, syncCoordinator: SyncCoordinator) {
        self.syncSettingsStore = syncSettingsStore
        self.syncCoordinator = syncCoordinator
        loadSettings()
    }

    func saveSettings() async {
        guard let syncSettingsStore, let syncCoordinator else {
            showSettingsMessage("sync.settings.error.saveFailed")
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
        defer { isSaving = false }

        let configuration = makeConfiguration()
        let draft = makeDraft(configuration: configuration)

        do {
            try syncSettingsStore.save(draft)

            if configuration.backupEnabled {
                syncSettingsStore.completeInitialSetup(.syncSpace)
                let secrets = currentSyncSecrets()
                let didImport = await syncCoordinator.importRemoteDataBeforeBackup(
                    configuration: configuration,
                    secrets: secrets
                )
                guard didImport else {
                    showSettingsMessage("sync.settings.savedButImportFailed")
                    return
                }

                let didBackup = await syncCoordinator.backupCurrentData(
                    configuration: configuration,
                    secrets: secrets,
                    forceFullUpload: false
                )
                showSettingsMessage(didBackup ? "sync.settings.savedAndBackedUp" : "sync.settings.savedButBackupFailed")
            } else {
                syncSettingsStore.completeInitialSetup(.localOnly)
                showSettingsMessage("sync.settings.saved")
            }
        } catch {
            showSettingsMessage("sync.settings.error.saveFailed")
        }
    }

    func testConnection() async {
        await runSyncAction {
            guard let syncCoordinator = self.syncCoordinator else {
                self.showSettingsMessage("sync.settings.error.saveFailed")
                return
            }

            _ = await syncCoordinator.testConnection(
                configuration: self.savedOrCurrentConfiguration(),
                secrets: self.currentSyncSecrets()
            )
        }
    }

    func backupNow() async {
        await runSyncAction {
            guard let syncCoordinator = self.syncCoordinator else {
                self.showSettingsMessage("sync.backup.error.failed")
                return
            }

            let configuration = self.savedOrCurrentConfiguration()
            let didBackup = await syncCoordinator.backupCurrentData(
                configuration: configuration,
                secrets: self.currentSyncSecrets(),
                forceFullUpload: true
            )
            self.showSettingsMessage(didBackup ? "sync.backup.succeeded" : "sync.backup.error.failed")
        }
    }

    func importNow() async {
        await runSyncAction {
            guard let syncSettingsStore = self.syncSettingsStore, let syncCoordinator = self.syncCoordinator else {
                self.showSettingsMessage("sync.import.error.failed")
                return
            }

            let configuration = self.savedOrCurrentConfiguration()
            let didImport = await syncCoordinator.importCurrentData(
                configuration: configuration,
                secrets: self.currentSyncSecrets(),
                manual: true
            )

            if didImport {
                do {
                    try syncSettingsStore.save(self.makeDraft(configuration: configuration))
                    syncSettingsStore.completeInitialSetup(.syncSpace)
                } catch {
                    self.showSettingsMessage("sync.settings.error.saveFailed")
                    return
                }
            }

            self.showSettingsMessage(didImport ? "sync.import.completed" : "sync.import.error.failed")
        }
    }

    func runLocalOnly() {
        guard let syncSettingsStore else {
            showSettingsMessage("sync.settings.error.saveFailed")
            return
        }

        isRunningSyncAction = true
        defer { isRunningSyncAction = false }

        backupEnabled = false
        autoImport = false
        backupOnChange = false

        var configuration = makeConfiguration()
        configuration.backupEnabled = false
        configuration.autoImport = false
        configuration.backupOnChange = false

        do {
            try syncSettingsStore.save(makeDraft(configuration: configuration))
            syncSettingsStore.completeInitialSetup(.localOnly)
            showSettingsMessage("sync.settings.localOnlySaved")
        } catch {
            showSettingsMessage("sync.settings.error.saveFailed")
        }
    }

    func isErrorMessage(_ key: String) -> Bool {
        key.contains(".error.")
    }

    var lastBackupText: String {
        guard let lastBackupAt = syncSettingsStore?.configuration.lastBackupAt else {
            return String(localized: "sync.lastSync.never")
        }

        return lastBackupAt.formatted(date: .abbreviated, time: .shortened)
    }

    var setupModeTextKey: LocalizedStringKey {
        switch syncSettingsStore?.setupChoice ?? .undecided {
        case .undecided:
            return "sync.setupMode.undecided"
        case .syncSpace:
            return "sync.setupMode.syncSpace"
        case .localOnly:
            return "sync.setupMode.localOnly"
        }
    }

    private func loadSettings() {
        guard let syncSettingsStore else { return }

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

    private func runSyncAction(_ action: @escaping () async -> Void) async {
        settingsMessageKey = nil
        isRunningSyncAction = true
        await action()
        isRunningSyncAction = false
    }

    private func savedOrCurrentConfiguration() -> SyncConfiguration {
        guard let syncSettingsStore else { return makeConfiguration() }

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
            lastBackupAt: syncSettingsStore?.configuration.lastBackupAt
        )
    }

    private func makeDraft(configuration: SyncConfiguration) -> SyncSettingsDraft {
        SyncSettingsDraft(
            configuration: configuration,
            password: password,
            accessToken: accessToken,
            encryptionPassword: encryptionEnabled ? encryptionPassword : ""
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
}
