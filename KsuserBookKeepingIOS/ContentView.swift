//
//  ContentView.swift
//  KsuserBookKeepingIOS
//
//  Created by Ksuserkqy on 2026/5/29.
//

import Combine
import SwiftUI

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var profileStore: ProfileStore
    @EnvironmentObject private var syncSettingsStore: SyncSettingsStore
    @EnvironmentObject private var draftBookkeepingStore: DraftBookkeepingStore
    @EnvironmentObject private var quickActionRouter: HomeScreenQuickActionRouter
    @AppStorage("app.language") private var language = AppLanguage.system.rawValue
    @AppStorage("app.theme") private var theme = AppTheme.system.rawValue
    @StateObject private var appLock = AppLockManager()
    @State private var isPrivacyCovered = false
    @State private var isImportingRemoteData = false
    @State private var lastRemoteDataImportAt: Date?
    @State private var isBackingUpLedgerData = false
    @State private var hasPendingLedgerDataBackup = false
    @State private var ledgerDataBackupTask: Task<Void, Never>?
    @State private var fallbackSyncTask: Task<Void, Never>?
    @State private var fallbackSyncConfiguration: SyncConfiguration?
    @State private var isShowingInitialSyncSetup = false
    @State private var selectedTab = AppTab.dashboard
    @State private var requestedRecordKind: DraftEntryKind?

    private var activeLocaleIdentifier: String {
        AppLanguage(rawValue: language)?.localeIdentifier ?? Locale.current.identifier
    }

    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                DashboardPage(
                    selectedTab: $selectedTab,
                    requestedRecordKind: $requestedRecordKind
                )
                .tabItem {
                    Label("tab.dashboard", systemImage: "house.fill")
                }
                .tag(AppTab.dashboard)

                TransactionsPage()
                .tabItem {
                    Label("tab.transactions", systemImage: "list.bullet.rectangle")
                }
                .tag(AppTab.transactions)

                RecordPage(
                    selectedTab: $selectedTab,
                    requestedKind: $requestedRecordKind
                )
                .tabItem {
                    Label("tab.record", systemImage: "plus.circle.fill")
                }
                .tag(AppTab.record)

                ReportsPage()
                .tabItem {
                    Label("tab.reports", systemImage: "chart.pie.fill")
                }
                .tag(AppTab.reports)

                ProfilePage()
                .tabItem {
                    Label("tab.profile", systemImage: "person.crop.circle")
                }
                .tag(AppTab.profile)
            }

            if appLock.isLocked {
                AppLockView(appLock: appLock)
                    .ignoresSafeArea()
                    .transition(.opacity)
            } else if isPrivacyCovered {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
            }
        }
        .dismissKeyboardOnBackgroundTap()
        .id(activeLocaleIdentifier)
        .tint(.accentColor)
        .environment(\.locale, Locale(identifier: activeLocaleIdentifier))
        .environmentObject(appLock)
        .preferredColorScheme(AppTheme(rawValue: theme)?.colorScheme)
        .task {
            quickActionRouter.configureShortcuts()
            handleQuickAction(quickActionRouter.pendingAction)
            if syncSettingsStore.needsInitialSyncSetup {
                isShowingInitialSyncSetup = true
            } else {
                await importRemoteDataIfNeeded(force: true)
            }
            restartFallbackSyncCheck()
        }
        .onChange(of: quickActionRouter.pendingAction) { _, action in
            handleQuickAction(action)
        }
        .onChange(of: syncSettingsStore.configuration) { _, _ in
            restartFallbackSyncCheck()
        }
        .onOpenURL { url in
            handleDeepLink(url)
        }
        .onReceive(draftBookkeepingStore.$localMetadataChangeToken.dropFirst()) { _ in
            scheduleLedgerDataBackup()
        }
        .onReceive(draftBookkeepingStore.$localTransactionsChangeToken.dropFirst()) { _ in
            scheduleLedgerDataBackup()
        }
        .onReceive(draftBookkeepingStore.$localTemplatesChangeToken.dropFirst()) { _ in
            scheduleLedgerDataBackup()
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                isPrivacyCovered = false
                appLock.refreshConfiguration()
                Task {
                    if syncSettingsStore.needsInitialSyncSetup {
                        isShowingInitialSyncSetup = true
                    } else {
                        await importRemoteDataIfNeeded()
                    }
                }
                restartFallbackSyncCheck()
            case .inactive:
                isPrivacyCovered = appLock.isPasswordEnabled && !appLock.isLocked
            case .background:
                isPrivacyCovered = false
                appLock.lockIfNeeded()
                fallbackSyncTask?.cancel()
                fallbackSyncTask = nil
                fallbackSyncConfiguration = nil
            @unknown default:
                break
            }
        }
        .fullScreenCover(isPresented: $isShowingInitialSyncSetup) {
            InitialSyncSetupPage {
                isShowingInitialSyncSetup = false
                Task {
                    await importRemoteDataIfNeeded(force: true)
                }
            }
            .environmentObject(profileStore)
            .environmentObject(syncSettingsStore)
            .environmentObject(draftBookkeepingStore)
        }
    }

    private func importRemoteDataIfNeeded(force: Bool = false) async {
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
        await profileStore.importIfRemoteProfileIsNewer(
            configuration: configuration,
            secrets: secrets
        )
        await draftBookkeepingStore.importIfRemoteMetadataIsNewer(
            configuration: configuration,
            secrets: secrets
        )
        await draftBookkeepingStore.importIfRemoteTransactionsAreNewer(
            configuration: configuration,
            secrets: secrets
        )
        await draftBookkeepingStore.importIfRemoteTemplatesAreNewer(
            configuration: configuration,
            secrets: secrets
        )
        lastRemoteDataImportAt = Date()
        isImportingRemoteData = false
    }

    private func restartFallbackSyncCheck() {
        let configuration = syncSettingsStore.configuration
        if
            fallbackSyncTask != nil,
            let fallbackSyncConfiguration,
            hasSameSyncParameters(fallbackSyncConfiguration, configuration)
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
        let configuration = syncSettingsStore.configuration
        guard hasSameSyncParameters(configuration, expectedConfiguration), configuration.backupEnabled else { return }

        if configuration.autoImport {
            await importRemoteDataIfNeeded(force: true)
        }

        if configuration.backupOnChange {
            await backupLedgerDataIfNeeded(configuration: configuration)
        }
    }

    private func handleQuickAction(_ action: HomeScreenQuickAction?) {
        guard let action else { return }

        requestedRecordKind = action.recordKind
        selectedTab = .record
        quickActionRouter.clearPendingAction()
    }

    private func handleDeepLink(_ url: URL) {
        guard url.scheme == WidgetDeepLink.scheme else { return }

        switch url.host {
        case "record":
            let kindValue = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?
                .first(where: { $0.name == "kind" })?
                .value
            if let kindValue, let kind = DraftEntryKind(rawValue: kindValue) {
                requestedRecordKind = kind
            } else {
                requestedRecordKind = .expense
            }
            selectedTab = .record
        case "reports":
            selectedTab = .reports
        case "transactions":
            selectedTab = .transactions
        case "dashboard":
            selectedTab = .dashboard
        default:
            break
        }
    }

    private func scheduleLedgerDataBackup() {
        let configuration = syncSettingsStore.configuration
        guard configuration.backupEnabled, configuration.backupOnChange else { return }

        guard !isBackingUpLedgerData else {
            hasPendingLedgerDataBackup = true
            return
        }

        ledgerDataBackupTask?.cancel()
        ledgerDataBackupTask = Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard !Task.isCancelled else { return }
            await backupLedgerDataIfNeeded(configuration: configuration)
        }
    }

    private func backupLedgerDataIfNeeded(configuration: SyncConfiguration) async {
        guard !isBackingUpLedgerData else {
            hasPendingLedgerDataBackup = true
            return
        }
        guard hasSameSyncParameters(configuration, syncSettingsStore.configuration) else { return }

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
            scheduleLedgerDataBackup()
        }
    }

    private func hasSameSyncParameters(_ lhs: SyncConfiguration, _ rhs: SyncConfiguration) -> Bool {
        lhs.backupEnabled == rhs.backupEnabled &&
            lhs.provider == rhs.provider &&
            lhs.webDAVAuthentication == rhs.webDAVAuthentication &&
            lhs.webDAVServerURL == rhs.webDAVServerURL &&
            lhs.webDAVUsername == rhs.webDAVUsername &&
            lhs.backupOnChange == rhs.backupOnChange &&
            lhs.autoImport == rhs.autoImport &&
            lhs.backupInterval == rhs.backupInterval &&
            lhs.encryptionEnabled == rhs.encryptionEnabled
    }
}

enum AppTab: Hashable {
    case dashboard
    case transactions
    case record
    case reports
    case profile
}

#Preview {
    ContentView()
        .environmentObject(ProfileStore())
        .environmentObject(SyncSettingsStore())
        .environmentObject(DraftBookkeepingStore())
        .environmentObject(HomeScreenQuickActionRouter.shared)
}
