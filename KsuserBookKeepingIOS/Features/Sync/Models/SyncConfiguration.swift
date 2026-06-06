import Foundation
import SwiftUI

enum SyncProvider: String, CaseIterable, Codable, Identifiable {
    case iCloudDrive
    case webDAV

    var id: String { rawValue }

    var titleKey: LocalizedStringKey {
        switch self {
        case .iCloudDrive:
            return "sync.provider.iCloudDrive"
        case .webDAV:
            return "sync.provider.webDAV"
        }
    }

    var isAvailable: Bool {
        switch self {
        case .iCloudDrive:
            return true
        case .webDAV:
            return true
        }
    }
}

enum WebDAVAuthentication: String, CaseIterable, Codable, Identifiable {
    case password
    case token

    var id: String { rawValue }

    var titleKey: LocalizedStringKey {
        switch self {
        case .password:
            return "sync.webDAV.authentication.password"
        case .token:
            return "sync.webDAV.authentication.token"
        }
    }
}

enum BackupInterval: String, CaseIterable, Codable, Identifiable {
    case oneMinute
    case fiveMinutes
    case tenMinutes

    var id: String { rawValue }

    var timeInterval: TimeInterval {
        switch self {
        case .oneMinute:
            return 60
        case .fiveMinutes:
            return 5 * 60
        case .tenMinutes:
            return 10 * 60
        }
    }

    var titleKey: LocalizedStringKey {
        switch self {
        case .oneMinute:
            return "sync.backupInterval.oneMinute"
        case .fiveMinutes:
            return "sync.backupInterval.fiveMinutes"
        case .tenMinutes:
            return "sync.backupInterval.tenMinutes"
        }
    }
}

enum SyncSetupChoice: String {
    case undecided
    case syncSpace
    case localOnly
}

struct SyncConfiguration: Codable, Equatable {
    var backupEnabled: Bool
    var provider: SyncProvider
    var webDAVAuthentication: WebDAVAuthentication
    var webDAVServerURL: String
    var webDAVUsername: String
    var backupOnChange: Bool
    var autoImport: Bool
    var backupInterval: BackupInterval
    var encryptionEnabled: Bool
    var lastBackupAt: Date?

    static let defaultValue = SyncConfiguration(
        backupEnabled: false,
        provider: .webDAV,
        webDAVAuthentication: .password,
        webDAVServerURL: "",
        webDAVUsername: "",
        backupOnChange: true,
        autoImport: true,
        backupInterval: .tenMinutes,
        encryptionEnabled: true,
        lastBackupAt: nil
    )
}

extension SyncConfiguration {
    func hasSameSyncParameters(as other: SyncConfiguration) -> Bool {
        backupEnabled == other.backupEnabled &&
            provider == other.provider &&
            webDAVAuthentication == other.webDAVAuthentication &&
            webDAVServerURL == other.webDAVServerURL &&
            webDAVUsername == other.webDAVUsername &&
            backupOnChange == other.backupOnChange &&
            autoImport == other.autoImport &&
            backupInterval == other.backupInterval &&
            encryptionEnabled == other.encryptionEnabled
    }
}

struct SyncSettingsDraft {
    var configuration: SyncConfiguration
    var password: String
    var accessToken: String
    var encryptionPassword: String
}

struct SyncSecrets {
    var webDAVSecret: String
    var encryptionPassword: String
}
