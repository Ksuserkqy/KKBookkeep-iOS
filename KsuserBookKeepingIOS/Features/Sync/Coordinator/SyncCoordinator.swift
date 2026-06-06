import Combine
import Foundation

@MainActor
final class SyncCoordinator: ObservableObject {
    @Published var isShowingInitialSyncSetup = false

    private weak var profileStore: ProfileStore?
    private weak var syncSettingsStore: SyncSettingsStore?
    private weak var draftBookkeepingStore: DraftBookkeepingStore?

    private var isImportingRemoteData = false
    private var lastRemoteDataImportAt: Date?
    private var isBackingUpLedgerData = false
    private var hasPendingLedgerDataBackup = false
    private var ledgerDataBackupTask: Task<Void, Never>?
    private var fallbackSyncTask: Task<Void, Never>?
    private var fallbackSyncConfiguration: SyncConfiguration?

    func configure(
        profileStore: ProfileStore,
        syncSettingsStore: SyncSettingsStore,
        draftBookkeepingStore: DraftBookkeepingStore
    ) {
        self.profileStore = profileStore
        self.syncSettingsStore = syncSettingsStore
        self.draftBookkeepingStore = draftBookkeepingStore
    }

    func startIfNeeded() {
        guard let syncSettingsStore else { return }

        if syncSettingsStore.needsInitialSyncSetup {
            isShowingInitialSyncSetup = true
        } else {
            Task {
                await importRemoteDataIfNeeded(force: true)
            }
        }

        restartFallbackSyncCheck()
    }

    func handleSceneBecameActive() {
        guard let syncSettingsStore else { return }

        if syncSettingsStore.needsInitialSyncSetup {
            isShowingInitialSyncSetup = true
        } else {
            Task {
                await importRemoteDataIfNeeded()
            }
        }

        restartFallbackSyncCheck()
    }

    func handleSceneEnteredBackground() {
        fallbackSyncTask?.cancel()
        fallbackSyncTask = nil
        fallbackSyncConfiguration = nil
    }

    func handleConfigurationChanged() {
        restartFallbackSyncCheck()
    }

    func completeInitialSyncSetupFlow() {
        isShowingInitialSyncSetup = false
        Task {
            await importRemoteDataIfNeeded(force: true)
            restartFallbackSyncCheck()
        }
    }

    func scheduleBackupAfterLocalChange() {
        guard
            let syncSettingsStore,
            syncSettingsStore.configuration.backupEnabled,
            syncSettingsStore.configuration.backupOnChange
        else {
            return
        }

        guard !isBackingUpLedgerData else {
            hasPendingLedgerDataBackup = true
            return
        }

        let configuration = syncSettingsStore.configuration
        ledgerDataBackupTask?.cancel()
        ledgerDataBackupTask = Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard !Task.isCancelled else { return }
            await backupLedgerDataIfNeeded(configuration: configuration)
        }
    }

    func backupNow(forceFullUpload: Bool) async -> Bool {
        guard
            let profileStore,
            let syncSettingsStore,
            let draftBookkeepingStore
        else {
            return false
        }

        let configuration = syncSettingsStore.configuration
        let secrets = syncSettingsStore.secrets(for: configuration)
        let profileBackedUp = await profileStore.backupNow(configuration: configuration, secrets: secrets)
        let ledgerDataBackedUp = await draftBookkeepingStore.backupLedgerDataNow(
            configuration: configuration,
            secrets: secrets,
            forceFullUpload: forceFullUpload
        )

        if profileBackedUp, ledgerDataBackedUp {
            try? syncSettingsStore.markBackupCompleted()
        }

        return profileBackedUp && ledgerDataBackedUp
    }

    func importNow(manual: Bool) async -> Bool {
        guard
            let profileStore,
            let syncSettingsStore,
            let draftBookkeepingStore
        else {
            return false
        }

        let configuration = syncSettingsStore.configuration
        let secrets = syncSettingsStore.secrets(for: configuration)
        let profileImported = manual
            ? await profileStore.importNow(configuration: configuration, secrets: secrets)
            : await profileStore.importRemoteProfileBeforeBackup(configuration: configuration, secrets: secrets)
        let metadataImported = await draftBookkeepingStore.importMetadataNow(configuration: configuration, secrets: secrets)
        let transactionsImported = await draftBookkeepingStore.importTransactionsNow(configuration: configuration, secrets: secrets)
        let templatesImported = await draftBookkeepingStore.importTemplatesNow(configuration: configuration, secrets: secrets)
        let budgetsImported = await draftBookkeepingStore.importBudgetsNow(configuration: configuration, secrets: secrets)

        return profileImported && metadataImported && transactionsImported && templatesImported && budgetsImported
    }

    func testConnection(configuration: SyncConfiguration, secrets: SyncSecrets) async -> Bool {
        guard let profileStore else { return false }
        return await profileStore.testSyncLocation(configuration: configuration, secrets: secrets)
    }

    func importRemoteDataBeforeBackup(configuration: SyncConfiguration, secrets: SyncSecrets) async -> Bool {
        guard
            let profileStore,
            let draftBookkeepingStore
        else {
            return false
        }

        let profileImported = await profileStore.importRemoteProfileBeforeBackup(
            configuration: configuration,
            secrets: secrets
        )
        let ledgerDataImported = await draftBookkeepingStore.importRemoteLedgerDataBeforeBackup(
            configuration: configuration,
            secrets: secrets
        )
        return profileImported && ledgerDataImported
    }

    func backupCurrentData(
        configuration: SyncConfiguration,
        secrets: SyncSecrets,
        forceFullUpload: Bool
    ) async -> Bool {
        guard
            let profileStore,
            let draftBookkeepingStore,
            let syncSettingsStore
        else {
            return false
        }

        let profileBackedUp = await profileStore.backupNow(configuration: configuration, secrets: secrets)
        let ledgerDataBackedUp = await draftBookkeepingStore.backupLedgerDataNow(
            configuration: configuration,
            secrets: secrets,
            forceFullUpload: forceFullUpload
        )
        if profileBackedUp, ledgerDataBackedUp {
            try? syncSettingsStore.markBackupCompleted()
        }
        return profileBackedUp && ledgerDataBackedUp
    }

    func importCurrentData(
        configuration: SyncConfiguration,
        secrets: SyncSecrets,
        manual: Bool
    ) async -> Bool {
        guard
            let profileStore,
            let draftBookkeepingStore
        else {
            return false
        }

        let profileImported = manual
            ? await profileStore.importNow(configuration: configuration, secrets: secrets)
            : await profileStore.importRemoteProfileBeforeBackup(configuration: configuration, secrets: secrets)
        let metadataImported = await draftBookkeepingStore.importMetadataNow(configuration: configuration, secrets: secrets)
        let transactionsImported = await draftBookkeepingStore.importTransactionsNow(configuration: configuration, secrets: secrets)
        let templatesImported = await draftBookkeepingStore.importTemplatesNow(configuration: configuration, secrets: secrets)
        let budgetsImported = await draftBookkeepingStore.importBudgetsNow(configuration: configuration, secrets: secrets)
        return profileImported && metadataImported && transactionsImported && templatesImported && budgetsImported
    }

    private func importRemoteDataIfNeeded(force: Bool = false) async {
        guard
            let profileStore,
            let syncSettingsStore,
            let draftBookkeepingStore
        else {
            return
        }

        let configuration = syncSettingsStore.configuration
        guard configuration.backupEnabled, configuration.autoImport else { return }
        guard !isImportingRemoteData else { return }

        if
            !force,
            let lastRemoteDataImportAt,
            Date().timeIntervalSince(lastRemoteDataImportAt) < 60
        {
            return
        }

        isImportingRemoteData = true
        let secrets = syncSettingsStore.secrets(for: configuration)
        await profileStore.importIfRemoteProfileIsNewer(configuration: configuration, secrets: secrets)
        await draftBookkeepingStore.importIfRemoteMetadataIsNewer(configuration: configuration, secrets: secrets)
        await draftBookkeepingStore.importIfRemoteTransactionsAreNewer(configuration: configuration, secrets: secrets)
        await draftBookkeepingStore.importIfRemoteTemplatesAreNewer(configuration: configuration, secrets: secrets)
        await draftBookkeepingStore.importIfRemoteBudgetsAreNewer(configuration: configuration, secrets: secrets)
        lastRemoteDataImportAt = Date()
        isImportingRemoteData = false
    }

    private func restartFallbackSyncCheck() {
        guard let syncSettingsStore else { return }

        let configuration = syncSettingsStore.configuration
        if
            fallbackSyncTask != nil,
            let fallbackSyncConfiguration,
            fallbackSyncConfiguration.hasSameSyncParameters(as: configuration)
        {
            return
        }

        fallbackSyncTask?.cancel()
        fallbackSyncTask = nil
        fallbackSyncConfiguration = nil

        guard configuration.backupEnabled, configuration.autoImport || configuration.backupOnChange else { return }

        fallbackSyncConfiguration = configuration
        fallbackSyncTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(configuration.backupInterval.timeInterval * 1_000_000_000))
                guard !Task.isCancelled else { return }
                await runFallbackSyncCheck(expectedConfiguration: configuration)
            }
        }
    }

    private func runFallbackSyncCheck(expectedConfiguration: SyncConfiguration) async {
        guard let syncSettingsStore else { return }

        let configuration = syncSettingsStore.configuration
        guard configuration.hasSameSyncParameters(as: expectedConfiguration), configuration.backupEnabled else { return }

        if configuration.autoImport {
            await importRemoteDataIfNeeded(force: true)
        }

        if configuration.backupOnChange {
            await backupLedgerDataIfNeeded(configuration: configuration)
        }
    }

    private func backupLedgerDataIfNeeded(configuration: SyncConfiguration) async {
        guard
            let syncSettingsStore,
            let draftBookkeepingStore
        else {
            return
        }

        guard !isBackingUpLedgerData else {
            hasPendingLedgerDataBackup = true
            return
        }
        guard configuration.hasSameSyncParameters(as: syncSettingsStore.configuration) else { return }

        isBackingUpLedgerData = true
        let didBackup = await draftBookkeepingStore.backupLedgerDataNow(
            configuration: configuration,
            secrets: syncSettingsStore.secrets(for: configuration)
        )
        if didBackup {
            try? syncSettingsStore.markBackupCompleted()
        }
        isBackingUpLedgerData = false

        if hasPendingLedgerDataBackup {
            hasPendingLedgerDataBackup = false
            scheduleBackupAfterLocalChange()
        }
    }
}
