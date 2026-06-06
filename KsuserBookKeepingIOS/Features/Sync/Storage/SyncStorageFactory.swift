import Foundation

enum SyncStorageFactory {
    static let iCloudContainerIdentifier = "iCloud.cn.ksuser.bookkeeping.kkbookkeep"

    static func storage(for configuration: SyncConfiguration, webDAVSecret: String) throws -> any SyncStorage {
        switch configuration.provider {
        case .iCloudDrive:
            return try iCloudDriveStorage()
        case .webDAV:
            guard !configuration.webDAVServerURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw SyncStorageError.webDAVNotConfigured
            }

            return WebDAVSyncStorage(
                serverURL: configuration.webDAVServerURL,
                authentication: configuration.webDAVAuthentication,
                username: configuration.webDAVUsername,
                secret: webDAVSecret
            )
        }
    }

    private static func iCloudDriveStorage(fileManager: FileManager = .default) throws -> any SyncStorage {
        guard let containerURL = iCloudContainerURL(fileManager: fileManager) else {
            throw SyncStorageError.providerUnavailable
        }

        let documentsURL = containerURL.appendingPathComponent("Documents", isDirectory: true)
        return ICloudDriveSyncStorage(rootURL: documentsURL, fileManager: fileManager)
    }

    private static func iCloudContainerURL(fileManager: FileManager = .default) -> URL? {
        fileManager.url(forUbiquityContainerIdentifier: iCloudContainerIdentifier)
    }
}
