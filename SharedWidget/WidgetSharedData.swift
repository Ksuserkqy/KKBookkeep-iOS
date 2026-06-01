import Foundation

enum WidgetSharedConfiguration {
    static let appGroupIdentifier = "group.cn.ksuser.bookkeeping.KsuserBookKeepingIOS"
    static let snapshotFileName = "widget-ledger-snapshot.json"

    static func snapshotURL(fileManager: FileManager = .default) -> URL? {
        let containerURL = fileManager.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)
        let directoryURL = containerURL ?? fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        return directoryURL?.appendingPathComponent(snapshotFileName)
    }
}

enum WidgetDeepLink {
    static let scheme = "kkbookkeep"

    static let dashboard = URL(string: "\(scheme)://dashboard")!
    static let reports = URL(string: "\(scheme)://reports")!

    static func record(kind: WidgetRecordKind) -> URL {
        URL(string: "\(scheme)://record?kind=\(kind.rawValue)")!
    }
}

enum WidgetRecordKind: String, CaseIterable, Codable, Identifiable {
    case expense
    case income
    case transfer

    var id: String { rawValue }
}

struct WidgetLedgerSnapshot: Codable, Equatable {
    var generatedAt: Date
    var totalBalanceText: String
    var monthIncomeText: String
    var monthExpenseText: String
    var monthBalanceText: String
    var todayExpenseText: String
    var monthTransactionCount: Int
    var topExpenseCategoryName: String?
    var topExpenseCategoryAmountText: String?
    var recentTransactions: [WidgetRecentTransaction]
    var dailyPoints: [WidgetDailyPoint]

    static let empty = WidgetLedgerSnapshot(
        generatedAt: Date(timeIntervalSince1970: 0),
        totalBalanceText: "¥0.00",
        monthIncomeText: "¥0.00",
        monthExpenseText: "¥0.00",
        monthBalanceText: "¥0.00",
        todayExpenseText: "¥0.00",
        monthTransactionCount: 0,
        topExpenseCategoryName: nil,
        topExpenseCategoryAmountText: nil,
        recentTransactions: [],
        dailyPoints: []
    )
}

struct WidgetRecentTransaction: Codable, Equatable, Identifiable {
    var id: String
    var kind: WidgetRecordKind
    var title: String
    var amountText: String
    var dateText: String
}

struct WidgetDailyPoint: Codable, Equatable, Identifiable {
    var day: Int
    var income: Double
    var expense: Double

    var id: Int { day }
}

enum WidgetSnapshotStore {
    static func load() -> WidgetLedgerSnapshot {
        guard
            let url = WidgetSharedConfiguration.snapshotURL(),
            let data = try? Data(contentsOf: url),
            let snapshot = try? decoder.decode(WidgetLedgerSnapshot.self, from: data)
        else {
            return .empty
        }

        return snapshot
    }

    static func save(_ snapshot: WidgetLedgerSnapshot) {
        guard
            let url = WidgetSharedConfiguration.snapshotURL(),
            let data = try? encoder.encode(snapshot)
        else {
            return
        }

        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            let temporaryURL = url.deletingLastPathComponent().appendingPathComponent(".\(WidgetSharedConfiguration.snapshotFileName).tmp")
            try data.write(to: temporaryURL, options: [.atomic])
            if FileManager.default.fileExists(atPath: url.path) {
                try? FileManager.default.removeItem(at: url)
            }
            try FileManager.default.moveItem(at: temporaryURL, to: url)
        } catch {
            try? data.write(to: url, options: [.atomic])
        }
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
