import CoreText
import Foundation
#if canImport(ActivityKit)
import ActivityKit
#endif

enum WidgetSharedConfiguration {
    static let appGroupIdentifier = "group.cn.ksuser.bookkeeping.KsuserBookKeepingIOS"
    static let snapshotFileName = "widget-ledger-snapshot.json"
    static let liveActivitiesEnabledKey = "app.liveActivities.enabled"

    static func snapshotURL(fileManager: FileManager = .default) -> URL? {
        let containerURL = fileManager.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)
        let directoryURL = containerURL ?? fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        return directoryURL?.appendingPathComponent(snapshotFileName)
    }
}

enum WidgetDeepLink {
    static let scheme = "kkbookkeep"

    static let dashboard = URL(string: "\(scheme)://dashboard")!
    static let transactions = URL(string: "\(scheme)://transactions")!
    static let reports = URL(string: "\(scheme)://reports")!

    static func record(kind: WidgetRecordKind) -> URL {
        URL(string: "\(scheme)://record?kind=\(kind.rawValue)")!
    }
}

enum WidgetRecordKind: String, CaseIterable, Codable, Identifiable, Sendable {
    case expense
    case income
    case transfer

    var id: String { rawValue }
}

#if canImport(ActivityKit)
struct RecentTransactionActivityAttributes: ActivityAttributes, Sendable {
    struct ContentState: Codable, Hashable, Sendable {
        var transactionId: String
        var kind: WidgetRecordKind
        var title: String
        var amountText: String
        var accountName: String
        var accountIconName: String
        var accountSymbolName: String
        var accountColorHex: String
        var categoryName: String?
        var counterpartyAccountName: String?
        var note: String
        var locationName: String?
        var dateText: String
    }

    var ledgerId: String
}
#endif

enum WidgetAccountIconMapper {
    static func glyph(for iconName: String) -> String {
        fontAwesomeGlyphs[iconName] ?? fontAwesomeGlyphs["wallet"] ?? "\u{f555}"
    }

    static func fontName(for iconName: String) -> String {
        switch iconName {
        case "alipay", "apple-pay", "cc-mastercard", "cc-visa", "google-pay", "paypal", "qq", "weixin":
            return "FontAwesome7Brands-Regular"
        default:
            return "FontAwesome7Free-Solid"
        }
    }

    static func systemImageName(for iconName: String) -> String {
        switch iconName {
        case "money-bill", "money-bill-wave":
            return "banknote.fill"
        case "money-check-dollar":
            return "checkmark.circle.fill"
        case "credit-card", "cc-visa", "cc-mastercard":
            return "creditcard.fill"
        case "wallet", "apple-pay", "google-pay", "paypal":
            return "wallet.pass.fill"
        case "building-columns", "landmark":
            return "building.columns.fill"
        case "mobile-screen-button":
            return "iphone.gen3"
        case "weixin", "qq", "alipay":
            return "qrcode"
        case "coins":
            return "dollarsign.circle.fill"
        case "piggy-bank", "sack-dollar", "vault":
            return "dollarsign.circle.fill"
        case "cash-register":
            return "dollarsign.square.fill"
        case "file-invoice-dollar":
            return "doc.text.fill"
        case "box-archive":
            return "archivebox.fill"
        case "chart-pie", "chart-line":
            return "chart.pie.fill"
        case "circle-dollar-to-slot":
            return "dollarsign.circle.fill"
        case "shield-halved":
            return "shield.fill"
        case "wifi":
            return "wifi"
        default:
            return "wallet.pass.fill"
        }
    }

    private static let fontAwesomeGlyphs = [
        "alipay": "\u{eebc}",
        "apple-pay": "\u{f415}",
        "box-archive": "\u{f187}",
        "building-columns": "\u{f19c}",
        "cash-register": "\u{f788}",
        "cc-mastercard": "\u{f1f1}",
        "cc-visa": "\u{f1f0}",
        "chart-line": "\u{f201}",
        "chart-pie": "\u{f200}",
        "circle-dollar-to-slot": "\u{f4b9}",
        "coins": "\u{f51e}",
        "credit-card": "\u{f09d}",
        "file-invoice-dollar": "\u{f571}",
        "google-pay": "\u{e079}",
        "landmark": "\u{f66f}",
        "mobile-screen-button": "\u{f3cd}",
        "money-bill": "\u{f0d6}",
        "money-bill-wave": "\u{f53a}",
        "money-check-dollar": "\u{f53d}",
        "paypal": "\u{f1ed}",
        "piggy-bank": "\u{f4d3}",
        "qq": "\u{f1d6}",
        "sack-dollar": "\u{f81d}",
        "shield-halved": "\u{f3ed}",
        "vault": "\u{e2c5}",
        "wallet": "\u{f555}",
        "weixin": "\u{f1d7}",
        "wifi": "\u{f1eb}"
    ]
}

enum WidgetFontAwesomeFontLoader {
    private static var didRegister = false

    static func registerIfNeeded() {
        guard !didRegister else { return }
        didRegister = true

        [
            ("FontAwesome7Free-Solid-900", "otf"),
            ("FontAwesome7Brands-Regular-400", "otf")
        ].forEach { name, ext in
            if let url = Bundle.main.url(forResource: name, withExtension: ext, subdirectory: "Resources/Fonts")
                ?? Bundle.main.url(forResource: name, withExtension: ext) {
                CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
            }
        }
    }
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
