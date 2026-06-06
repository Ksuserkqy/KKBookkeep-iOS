//
//  KsuserBookKeepingIOSApp.swift
//  KsuserBookKeepingIOS
//
//  Created by Ksuserkqy on 2026/5/29.
//

import Combine
import SwiftUI
import UIKit

@MainActor
final class HomeScreenQuickActionRouter: ObservableObject {
    static let shared = HomeScreenQuickActionRouter()

    @Published private(set) var pendingAction: HomeScreenQuickAction?

    private init() {}

    func configureShortcuts() {
        UIApplication.shared.shortcutItems = HomeScreenQuickAction.allCases.map { action in
            UIApplicationShortcutItem(
                type: action.type,
                localizedTitle: NSLocalizedString(action.titleKey, comment: ""),
                localizedSubtitle: nil,
                icon: UIApplicationShortcutIcon(systemImageName: action.systemImageName),
                userInfo: nil
            )
        }
    }

    @discardableResult
    func handle(_ shortcutItem: UIApplicationShortcutItem) -> Bool {
        guard let action = HomeScreenQuickAction(type: shortcutItem.type) else {
            return false
        }

        pendingAction = action
        return true
    }

    func clearPendingAction() {
        pendingAction = nil
    }
}

enum HomeScreenQuickAction: String, CaseIterable, Equatable {
    case expense
    case income
    case transfer

    private static let typePrefix = "cn.ksuser.bookkeeping.KsuserBookKeepingIOS.quickAction."

    var type: String {
        Self.typePrefix + rawValue
    }

    init?(type: String) {
        guard type.hasPrefix(Self.typePrefix) else { return nil }
        self.init(rawValue: String(type.dropFirst(Self.typePrefix.count)))
    }

    var titleKey: String {
        switch self {
        case .expense:
            return "quickAction.expense.title"
        case .income:
            return "quickAction.income.title"
        case .transfer:
            return "quickAction.transfer.title"
        }
    }

    var systemImageName: String {
        switch self {
        case .expense:
            return "minus.circle.fill"
        case .income:
            return "plus.circle.fill"
        case .transfer:
            return "arrow.left.arrow.right.circle.fill"
        }
    }

    var recordKind: DraftEntryKind {
        switch self {
        case .expense:
            return .expense
        case .income:
            return .income
        case .transfer:
            return .transfer
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(
            name: nil,
            sessionRole: connectingSceneSession.role
        )
        configuration.delegateClass = QuickActionSceneDelegate.self
        return configuration
    }

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        if let shortcutItem = launchOptions?[.shortcutItem] as? UIApplicationShortcutItem {
            Task { @MainActor in
                HomeScreenQuickActionRouter.shared.handle(shortcutItem)
            }
        }

        return true
    }

    func application(
        _ application: UIApplication,
        performActionFor shortcutItem: UIApplicationShortcutItem,
        completionHandler: @escaping (Bool) -> Void
    ) {
        Task { @MainActor in
            let didHandle = HomeScreenQuickActionRouter.shared.handle(shortcutItem)
            completionHandler(didHandle)
        }
    }
}

final class QuickActionSceneDelegate: NSObject, UIWindowSceneDelegate {
    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        if let shortcutItem = connectionOptions.shortcutItem {
            Task { @MainActor in
                HomeScreenQuickActionRouter.shared.handle(shortcutItem)
            }
        }
    }

    func windowScene(
        _ windowScene: UIWindowScene,
        performActionFor shortcutItem: UIApplicationShortcutItem,
        completionHandler: @escaping (Bool) -> Void
    ) {
        Task { @MainActor in
            let didHandle = HomeScreenQuickActionRouter.shared.handle(shortcutItem)
            completionHandler(didHandle)
        }
    }
}

@main
struct KsuserBookKeepingIOSApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var profileStore = ProfileStore()
    @StateObject private var syncSettingsStore = SyncSettingsStore()
    @StateObject private var aiModelSettingsStore = AIModelSettingsStore()
    @StateObject private var draftBookkeepingStore = DraftBookkeepingStore()
    @StateObject private var syncCoordinator = SyncCoordinator()
    @StateObject private var quickActionRouter = HomeScreenQuickActionRouter.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(profileStore)
                .environmentObject(syncSettingsStore)
                .environmentObject(aiModelSettingsStore)
                .environmentObject(draftBookkeepingStore)
                .environmentObject(syncCoordinator)
                .environmentObject(quickActionRouter)
        }
    }
}
