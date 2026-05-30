import Foundation
import SwiftUI

struct PersonalProfile: Codable, Equatable {
    var displayName: String
    var email: String
    var avatarImageDataBase64: String?
    var currency: ProfileCurrency
    var timeZone: ProfileTimeZone
    var note: String
    var revision: Int
    var updatedAt: Date
    var updatedByDeviceId: String

    static func empty(deviceId: String = DeviceIdentity.currentDeviceId) -> PersonalProfile {
        PersonalProfile(
            displayName: "",
            email: "",
            avatarImageDataBase64: nil,
            currency: .cny,
            timeZone: .shanghai,
            note: "",
            revision: 0,
            updatedAt: Date(timeIntervalSince1970: 0),
            updatedByDeviceId: deviceId
        )
    }

    func isNewer(than other: PersonalProfile) -> Bool {
        if updatedAt != other.updatedAt {
            return updatedAt > other.updatedAt
        }

        if revision != other.revision {
            return revision > other.revision
        }

        return updatedByDeviceId > other.updatedByDeviceId
    }
}

struct PersonalProfileSyncDocument: Codable {
    let schemaVersion: Int
    let entity: String
    let profile: PersonalProfile

    init(profile: PersonalProfile) {
        self.schemaVersion = 1
        self.entity = "personalProfile"
        self.profile = profile
    }
}

enum ProfileCurrency: String, CaseIterable, Codable, Identifiable {
    case cny
    case usd
    case eur
    case jpy

    var id: String { rawValue }

    var titleKey: LocalizedStringKey {
        switch self {
        case .cny:
            return "profile.edit.currency.cny"
        case .usd:
            return "profile.edit.currency.usd"
        case .eur:
            return "profile.edit.currency.eur"
        case .jpy:
            return "profile.edit.currency.jpy"
        }
    }
}

enum ProfileTimeZone: String, CaseIterable, Codable, Identifiable {
    case shanghai
    case current
    case utc

    var id: String { rawValue }

    var titleKey: LocalizedStringKey {
        switch self {
        case .shanghai:
            return "profile.edit.timeZone.shanghai"
        case .current:
            return "profile.edit.timeZone.current"
        case .utc:
            return "profile.edit.timeZone.utc"
        }
    }
}

enum DeviceIdentity {
    private static let defaultsKey = "sync.deviceId"

    static var currentDeviceId: String {
        if let stored = UserDefaults.standard.string(forKey: defaultsKey), !stored.isEmpty {
            return stored
        }

        let newValue = UUID().uuidString
        UserDefaults.standard.set(newValue, forKey: defaultsKey)
        return newValue
    }
}
