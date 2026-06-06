import Combine
import Foundation

@MainActor
final class ProfileStore: ObservableObject {
    @Published private(set) var profile: PersonalProfile
    @Published private(set) var messageKey: String?

    private let repository: ProfileRepository
    private let syncService: ProfileSyncService
    private var syncState: ProfileSyncState

    init() {
        let repository = ProfileRepository()
        self.repository = repository
        self.syncService = ProfileSyncService()
        self.profile = repository.load()
        self.syncState = repository.loadSyncState()
    }

    init(repository: ProfileRepository, syncService: ProfileSyncService) {
        self.repository = repository
        self.syncService = syncService
        self.profile = repository.load()
        self.syncState = repository.loadSyncState()
    }

    func clearMessage() {
        messageKey = nil
    }

    func resetLocalProfile() throws {
        let emptyProfile = PersonalProfile.empty()
        try repository.save(emptyProfile)
        try repository.saveSyncState(.empty)
        profile = emptyProfile
        syncState = .empty
        messageKey = nil
    }

    func save(
        displayName: String,
        email: String,
        avatarImageDataBase64: String?,
        currency: ProfileCurrency,
        timeZone: ProfileTimeZone,
        note: String,
        syncConfiguration: SyncConfiguration?,
        syncSecrets: SyncSecrets
    ) async -> Bool {
        var nextProfile = profile
        nextProfile.displayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        nextProfile.email = email.trimmingCharacters(in: .whitespacesAndNewlines)
        nextProfile.avatarImageDataBase64 = avatarImageDataBase64
        nextProfile.currency = currency
        nextProfile.timeZone = timeZone
        nextProfile.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        nextProfile.revision += 1
        nextProfile.updatedAt = Date()
        nextProfile.updatedByDeviceId = DeviceIdentity.currentDeviceId

        do {
            let oldProfile = profile
            try repository.save(nextProfile)
            profile = nextProfile
            appendLocalProfileOps(from: oldProfile, to: nextProfile, occurredAt: nextProfile.updatedAt)

            if let syncConfiguration, syncConfiguration.backupEnabled, syncConfiguration.backupOnChange {
                do {
                    try await backupPendingProfileOps(configuration: syncConfiguration, secrets: syncSecrets, forceFullUpload: false)
                    messageKey = "profile.sync.savedAndBackedUp"
                } catch {
                    messageKey = "profile.sync.error.backupFailed"
                }
            } else {
                messageKey = "profile.sync.savedLocally"
            }

            return true
        } catch {
            messageKey = "profile.sync.error.saveFailed"
            return false
        }
    }

    @discardableResult
    func backupNow(configuration: SyncConfiguration, secrets: SyncSecrets) async -> Bool {
        guard configuration.backupEnabled else {
            messageKey = "profile.sync.error.backupDisabled"
            return false
        }

        do {
            try await backupPendingProfileOps(configuration: configuration, secrets: secrets, forceFullUpload: true)
            messageKey = "profile.sync.backupSucceeded"
            return true
        } catch {
            messageKey = "profile.sync.error.backupFailed"
            return false
        }
    }

    @discardableResult
    func importNow(configuration: SyncConfiguration, secrets: SyncSecrets) async -> Bool {
        guard configuration.backupEnabled else {
            messageKey = "profile.sync.error.backupDisabled"
            return false
        }

        do {
            let didImport = try await importProfileData(configuration: configuration, secrets: secrets, manual: true)
            guard didImport else {
                messageKey = "profile.sync.importNoRemoteProfile"
                return true
            }

            messageKey = "profile.sync.importSucceeded"
            return true
        } catch {
            messageKey = "profile.sync.error.importFailed"
            return false
        }
    }

    @discardableResult
    func importIfRemoteProfileIsNewer(configuration: SyncConfiguration, secrets: SyncSecrets) async -> Bool {
        guard configuration.backupEnabled else { return true }

        do {
            if try await importProfileData(configuration: configuration, secrets: secrets, manual: false) {
                messageKey = "profile.sync.importSucceeded"
            }
            return true
        } catch {
            messageKey = "profile.sync.error.importFailed"
            return false
        }
    }

    @discardableResult
    func importRemoteProfileBeforeBackup(configuration: SyncConfiguration, secrets: SyncSecrets) async -> Bool {
        guard configuration.backupEnabled else {
            messageKey = "profile.sync.error.backupDisabled"
            return false
        }

        do {
            if try await importProfileData(configuration: configuration, secrets: secrets, manual: false) {
                messageKey = "profile.sync.importSucceeded"
            }

            return true
        } catch {
            messageKey = "profile.sync.error.importFailed"
            return false
        }
    }

    @discardableResult
    func testSyncLocation(configuration: SyncConfiguration, secrets: SyncSecrets) async -> Bool {
        guard configuration.backupEnabled else {
            messageKey = "profile.sync.error.backupDisabled"
            return false
        }

        do {
            try await syncService.testConnection(configuration: configuration, secrets: secrets)
            messageKey = "profile.sync.testSucceeded"
            return true
        } catch {
            messageKey = "profile.sync.error.testFailed"
            return false
        }
    }

    private func appendLocalProfileOps(from oldProfile: PersonalProfile, to newProfile: PersonalProfile, occurredAt: Date) {
        var didAppend = false
        for field in PersonalProfileField.allCases where oldProfile.fieldValue(for: field) != newProfile.fieldValue(for: field) {
            let op = PersonalProfileOp(
                deviceId: DeviceIdentity.currentDeviceId,
                seq: syncState.nextSeq,
                field: field,
                occurredAt: occurredAt,
                payload: newProfile.fieldValue(for: field)
            )
            syncState.nextSeq += 1
            syncState.localOps.append(op)
            syncState.processedOpIds.insert(op.opId)
            syncState.fieldSortKeys[field.rawValue] = op.sortKey
            didAppend = true
        }

        if didAppend {
            persistSyncState()
        }
    }

    private func initializeProfileSyncStateIfNeeded() {
        guard syncState.localOps.isEmpty, syncState.processedOpIds.isEmpty else { return }
        let occurredAt = profile.updatedAt
        for field in PersonalProfileField.allCases {
            let op = PersonalProfileOp(
                deviceId: DeviceIdentity.currentDeviceId,
                seq: syncState.nextSeq,
                field: field,
                occurredAt: occurredAt,
                createdAt: occurredAt,
                payload: profile.fieldValue(for: field)
            )
            syncState.nextSeq += 1
            syncState.localOps.append(op)
            syncState.processedOpIds.insert(op.opId)
            syncState.fieldSortKeys[field.rawValue] = op.sortKey
        }
        persistSyncState()
    }

    private func backupPendingProfileOps(
        configuration: SyncConfiguration,
        secrets: SyncSecrets,
        forceFullUpload: Bool
    ) async throws {
        initializeProfileSyncStateIfNeeded()
        let ops = forceFullUpload
            ? syncState.localOps
            : syncState.localOps.filter { !syncState.uploadedOpIds.contains($0.opId) }
        guard !ops.isEmpty else { return }

        try await syncService.backup(ops: ops, configuration: configuration, secrets: secrets)
        syncState.uploadedOpIds.formUnion(ops.map(\.opId))
        persistSyncState()
    }

    @discardableResult
    private func importProfileData(configuration: SyncConfiguration, secrets: SyncSecrets, manual: Bool) async throws -> Bool {
        var didChange = false

        if let remoteProfile = try await syncService.importProfile(configuration: configuration, secrets: secrets) {
            if manual || remoteProfile.isNewer(than: profile) {
                try applyRemoteProfileSnapshot(remoteProfile)
                didChange = true
            }
        }

        let remoteOps = try await syncService.importOps(configuration: configuration, secrets: secrets)
        let unappliedOps = remoteOps
            .filter { !syncState.processedOpIds.contains($0.opId) }
            .sorted(by: JSONLSyncLogService<PersonalProfileOp>.opSort)

        for op in unappliedOps {
            didChange = applyRemoteProfileOp(op) || didChange
        }

        if didChange {
            try repository.save(profile)
            persistSyncState()
        }

        return didChange || !remoteOps.isEmpty
    }

    private func applyRemoteProfileSnapshot(_ remoteProfile: PersonalProfile) throws {
        profile = remoteProfile
        for field in PersonalProfileField.allCases {
            let key = ProfileOpSortKey(
                occurredAt: remoteProfile.updatedAt,
                deviceId: remoteProfile.updatedByDeviceId,
                seq: remoteProfile.revision
            )
            if key >= (syncState.fieldSortKeys[field.rawValue] ?? .zero) {
                syncState.fieldSortKeys[field.rawValue] = key
            }
        }
        try repository.save(remoteProfile)
        persistSyncState()
    }

    @discardableResult
    private func applyRemoteProfileOp(_ op: PersonalProfileOp) -> Bool {
        guard op.schemaVersion == 1, op.entity == "personalProfile", op.action == "update" else { return false }
        guard !op.deviceId.isEmpty, op.seq > 0, let payload = op.payload else { return false }
        guard !syncState.processedOpIds.contains(op.opId) else { return false }

        syncState.processedOpIds.insert(op.opId)
        let currentKey = syncState.fieldSortKeys[op.field.rawValue] ?? .zero
        guard op.sortKey >= currentKey else {
            persistSyncState()
            return false
        }

        var updatedProfile = profile
        updatedProfile.apply(payload, to: op.field)
        updatedProfile.revision += 1
        updatedProfile.updatedAt = max(updatedProfile.updatedAt, op.occurredAt)
        updatedProfile.updatedByDeviceId = op.deviceId
        profile = updatedProfile
        syncState.fieldSortKeys[op.field.rawValue] = op.sortKey
        return true
    }

    private func persistSyncState() {
        do {
            try repository.saveSyncState(syncState)
        } catch {
            assertionFailure("Failed to save profile sync state: \(error)")
        }
    }
}

struct ProfileRepository {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func load() -> PersonalProfile {
        guard
            let data = try? Data(contentsOf: profileURL()),
            let document = try? Self.decoder.decode(PersonalProfileSyncDocument.self, from: data)
        else {
            return .empty()
        }

        return document.profile
    }

    func loadSyncState() -> ProfileSyncState {
        guard
            let data = try? Data(contentsOf: syncStateURL()),
            let state = try? Self.decoder.decode(ProfileSyncState.self, from: data)
        else {
            return .empty
        }

        return state
    }

    func save(_ profile: PersonalProfile) throws {
        let fileURL = profileURL()
        try fileManager.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let data = try Self.encoder.encode(PersonalProfileSyncDocument(profile: profile))
        try data.write(to: fileURL, options: [.atomic, .completeFileProtection])
    }

    func saveSyncState(_ state: ProfileSyncState) throws {
        let fileURL = syncStateURL()
        try fileManager.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let data = try Self.encoder.encode(state)
        try data.write(to: fileURL, options: [.atomic, .completeFileProtection])
    }

    private func profileURL() -> URL {
        let baseURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return baseURL
            .appendingPathComponent("KKBookkeep", isDirectory: true)
            .appendingPathComponent("Profile", isDirectory: true)
            .appendingPathComponent("personal-profile.json")
    }

    private func syncStateURL() -> URL {
        let baseURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return baseURL
            .appendingPathComponent("KKBookkeep", isDirectory: true)
            .appendingPathComponent("Profile", isDirectory: true)
            .appendingPathComponent("profile-sync-state.json")
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
