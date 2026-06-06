import Foundation

enum PersonalProfileField: String, CaseIterable, Codable {
    case displayName
    case email
    case avatarImageDataBase64
    case currency
    case timeZone
    case note
}

struct PersonalProfileFieldValue: Codable, Equatable {
    var stringValue: String?

    init(stringValue: String?) {
        self.stringValue = stringValue
    }
}

struct PersonalProfileOp: SyncLogOperation, Codable, Equatable, Identifiable {
    let schemaVersion: Int
    var opId: String
    var deviceId: String
    var seq: Int
    var entity: String
    var entityId: String
    var action: String
    var field: PersonalProfileField
    var occurredAt: Date
    var createdAt: Date
    var payload: PersonalProfileFieldValue?

    var id: String { opId }

    init(
        opId: String = UUID().uuidString,
        deviceId: String,
        seq: Int,
        field: PersonalProfileField,
        occurredAt: Date,
        createdAt: Date = Date(),
        payload: PersonalProfileFieldValue?
    ) {
        self.schemaVersion = 1
        self.opId = opId
        self.deviceId = deviceId
        self.seq = seq
        self.entity = "personalProfile"
        self.entityId = "default"
        self.action = "update"
        self.field = field
        self.occurredAt = occurredAt
        self.createdAt = createdAt
        self.payload = payload
    }

    var fileIndex: Int {
        max(0, (seq - 1) / ProfileSyncService.opsPerFile)
    }

    var sortKey: ProfileOpSortKey {
        ProfileOpSortKey(occurredAt: occurredAt, deviceId: deviceId, seq: seq)
    }
}

struct ProfileOpSortKey: Codable, Equatable, Comparable {
    var occurredAt: Date
    var deviceId: String
    var seq: Int

    static let zero = ProfileOpSortKey(
        occurredAt: Date(timeIntervalSince1970: 0),
        deviceId: "",
        seq: 0
    )

    static func < (lhs: ProfileOpSortKey, rhs: ProfileOpSortKey) -> Bool {
        if lhs.occurredAt != rhs.occurredAt {
            return lhs.occurredAt < rhs.occurredAt
        }

        if lhs.deviceId != rhs.deviceId {
            return lhs.deviceId < rhs.deviceId
        }

        return lhs.seq < rhs.seq
    }
}

struct ProfileSyncState: Codable, Equatable {
    var nextSeq: Int = 1
    var localOps: [PersonalProfileOp] = []
    var uploadedOpIds: Set<String> = []
    var processedOpIds: Set<String> = []
    var fieldSortKeys: [String: ProfileOpSortKey] = [:]

    static let empty = ProfileSyncState()
}
