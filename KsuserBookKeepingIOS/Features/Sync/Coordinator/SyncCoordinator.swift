import Combine
import Foundation

@MainActor
final class SyncCoordinator: ObservableObject {
    @Published var isShowingInitialSyncSetup = false
    @Published private(set) var isRunningLaunchImport = false

    private weak var profileStore: ProfileStore?
    private weak var syncSettingsStore: SyncSettingsStore?
    private weak var draftBookkeepingStore: DraftBookkeepingStore?

    private var isImportingRemoteData = false
    private var lastRemoteDataImportAt: Date?
    private var isBackingUpLedgerData = false
    private var hasPendingLedgerDataBackup = false
    private var isBackupSchedulingSuspended = false
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
                await runLaunchImport()
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
        guard !isBackupSchedulingSuspended else { return }
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
            return await importRemoteDataAfterSuccessfulBackupIfNeeded(configuration: configuration)
        }

        return false
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

    func refreshNow() async -> Bool {
        guard let syncSettingsStore else { return false }

        let configuration = syncSettingsStore.configuration
        guard configuration.backupEnabled else { return true }

        _ = await backupNow(forceFullUpload: false)
        return await importNow(manual: false)
    }

    func testConnection(configuration: SyncConfiguration, secrets: SyncSecrets) async -> Bool {
        guard let profileStore else { return false }
        return await profileStore.testSyncLocation(configuration: configuration, secrets: secrets)
    }

    func hasRemoteData(configuration: SyncConfiguration, secrets: SyncSecrets) async -> Bool {
        do {
            let storage = try SyncStorageFactory.storage(for: configuration, webDAVSecret: secrets.webDAVSecret)
            if (try? await storage.readFile(at: "KKBookKeep/v1/profile/personal-profile.json")) != nil {
                return true
            }

            let directories = [
                "KKBookKeep/v1/profile-devices",
                "KKBookKeep/v1/ledgers/default/metadata-devices",
                "KKBookKeep/v1/ledgers/default/devices",
                "KKBookKeep/v1/ledgers/default/template-devices",
                "KKBookKeep/v1/ledgers/default/budget-devices"
            ]

            for directory in directories {
                if let deviceIds = try? await storage.listDirectories(at: directory), !deviceIds.isEmpty {
                    return true
                }
            }
        } catch {
            return false
        }

        return false
    }

    func clearRemoteBackupData(configuration: SyncConfiguration, secrets: SyncSecrets) async -> Bool {
        guard configuration.backupEnabled else { return true }

        do {
            let storage = try SyncStorageFactory.storage(for: configuration, webDAVSecret: secrets.webDAVSecret)
            try await deleteRemoteSyncTree(storage: storage, path: "KKBookKeep/v1")
            return true
        } catch {
            return false
        }
    }

    func suspendBackupSchedulingForLocalReset() {
        isBackupSchedulingSuspended = true
        hasPendingLedgerDataBackup = false
        ledgerDataBackupTask?.cancel()
        ledgerDataBackupTask = nil
    }

    func resumeBackupSchedulingAfterLocalReset() {
        isBackupSchedulingSuspended = false
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
            return await importRemoteDataAfterSuccessfulBackupIfNeeded(configuration: configuration)
        }
        return false
    }

    func importAfterBackupIfEnabled(configuration: SyncConfiguration) async -> Bool {
        await importRemoteDataAfterSuccessfulBackupIfNeeded(configuration: configuration)
    }

    private func runLaunchImport() async {
        guard !isRunningLaunchImport else { return }

        isRunningLaunchImport = true
        defer { isRunningLaunchImport = false }

        await importRemoteDataIfNeeded(force: true)
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

    @discardableResult
    private func importRemoteDataIfNeeded(force: Bool = false) async -> Bool {
        guard
            let profileStore,
            let syncSettingsStore,
            let draftBookkeepingStore
        else {
            return false
        }

        let configuration = syncSettingsStore.configuration
        guard configuration.backupEnabled, configuration.autoImport else { return true }
        guard !isImportingRemoteData else { return true }

        if
            !force,
            let lastRemoteDataImportAt,
            Date().timeIntervalSince(lastRemoteDataImportAt) < 60
        {
            return true
        }

        isImportingRemoteData = true
        defer { isImportingRemoteData = false }

        let secrets = syncSettingsStore.secrets(for: configuration)
        let profileImported = await profileStore.importIfRemoteProfileIsNewer(configuration: configuration, secrets: secrets)
        let metadataImported = await draftBookkeepingStore.importIfRemoteMetadataIsNewer(configuration: configuration, secrets: secrets)
        let transactionsImported = await draftBookkeepingStore.importIfRemoteTransactionsAreNewer(configuration: configuration, secrets: secrets)
        let templatesImported = await draftBookkeepingStore.importIfRemoteTemplatesAreNewer(configuration: configuration, secrets: secrets)
        let budgetsImported = await draftBookkeepingStore.importIfRemoteBudgetsAreNewer(configuration: configuration, secrets: secrets)
        let didImport = profileImported && metadataImported && transactionsImported && templatesImported && budgetsImported
        if didImport {
            lastRemoteDataImportAt = Date()
        }
        return didImport
    }

    private func importRemoteDataAfterSuccessfulBackupIfNeeded(configuration: SyncConfiguration) async -> Bool {
        guard
            let syncSettingsStore,
            configuration.autoImport,
            configuration.hasSameSyncParameters(as: syncSettingsStore.configuration)
        else {
            return true
        }

        return await importRemoteDataIfNeeded(force: true)
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
            _ = await importRemoteDataAfterSuccessfulBackupIfNeeded(configuration: configuration)
        }
        isBackingUpLedgerData = false

        if hasPendingLedgerDataBackup {
            hasPendingLedgerDataBackup = false
            scheduleBackupAfterLocalChange()
        }
    }

    private func deleteRemoteSyncTree(storage: SyncStorage, path: String) async throws {
        let files = try await remoteFiles(storage: storage, path: path)
        for file in files {
            try await storage.deleteFile(at: "\(path)/\(file)")
        }

        let directories = try await remoteDirectories(storage: storage, path: path)
        for directory in directories {
            try await deleteRemoteSyncTree(storage: storage, path: "\(path)/\(directory)")
        }

        if path != "KKBookKeep/v1" {
            try? await storage.deleteFile(at: path)
        }
    }

    private func remoteFiles(storage: SyncStorage, path: String) async throws -> [String] {
        do {
            return try await storage.listFiles(at: path)
        } catch SyncStorageError.fileNotFound {
            return []
        }
    }

    private func remoteDirectories(storage: SyncStorage, path: String) async throws -> [String] {
        do {
            return try await storage.listDirectories(at: path)
        } catch SyncStorageError.fileNotFound {
            return []
        }
    }
}
