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
    @EnvironmentObject private var syncCoordinator: SyncCoordinator
    @EnvironmentObject private var quickActionRouter: HomeScreenQuickActionRouter
    @AppStorage("app.language") private var language = AppLanguage.system.rawValue
    @AppStorage("app.theme") private var theme = AppTheme.system.rawValue
    @StateObject private var appLock = AppLockManager()
    @State private var isPrivacyCovered = false
    @State private var isShowingLaunchLoading = false
    @State private var launchLoadingDelayTask: Task<Void, Never>?
    @State private var selectedTab = AppTab.dashboard
    @State private var requestedRecordKind: DraftEntryKind?

    private var activeLocaleIdentifier: String {
        AppLocalization.localeIdentifier
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

            if isShowingLaunchLoading {
                AppLaunchLoadingView()
                    .transition(.opacity)
                    .zIndex(1)
            }

            if appLock.isLocked {
                AppLockView(appLock: appLock)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .zIndex(2)
            } else if isPrivacyCovered {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                    .zIndex(2)
            }
        }
        .dismissKeyboardOnBackgroundTap()
        .id(activeLocaleIdentifier)
        .tint(.accentColor)
        .environment(\.locale, Locale(identifier: activeLocaleIdentifier))
        .environmentObject(appLock)
        .preferredColorScheme(AppTheme(rawValue: theme)?.colorScheme)
        .task {
            syncCoordinator.configure(
                profileStore: profileStore,
                syncSettingsStore: syncSettingsStore,
                draftBookkeepingStore: draftBookkeepingStore
            )
            quickActionRouter.configureShortcuts()
            handleQuickAction(quickActionRouter.pendingAction)
            syncCoordinator.startIfNeeded()
        }
        .onChange(of: quickActionRouter.pendingAction) { _, action in
            handleQuickAction(action)
        }
        .onChange(of: syncSettingsStore.configuration) { _, _ in
            syncCoordinator.handleConfigurationChanged()
        }
        .onChange(of: syncCoordinator.isRunningLaunchImport) { _, isRunning in
            updateLaunchLoadingVisibility(isRunning: isRunning)
        }
        .onOpenURL { url in
            handleDeepLink(url)
        }
        .onReceive(draftBookkeepingStore.$localMetadataChangeToken.dropFirst()) { _ in
            syncCoordinator.scheduleBackupAfterLocalChange()
        }
        .onReceive(draftBookkeepingStore.$localTransactionsChangeToken.dropFirst()) { _ in
            syncCoordinator.scheduleBackupAfterLocalChange()
        }
        .onReceive(draftBookkeepingStore.$localTemplatesChangeToken.dropFirst()) { _ in
            syncCoordinator.scheduleBackupAfterLocalChange()
        }
        .onReceive(draftBookkeepingStore.$localBudgetsChangeToken.dropFirst()) { _ in
            syncCoordinator.scheduleBackupAfterLocalChange()
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                isPrivacyCovered = false
                appLock.refreshConfiguration()
                syncCoordinator.handleSceneBecameActive()
            case .inactive:
                isPrivacyCovered = appLock.isPasswordEnabled && !appLock.isLocked
            case .background:
                isPrivacyCovered = false
                appLock.lockIfNeeded()
                syncCoordinator.handleSceneEnteredBackground()
            @unknown default:
                break
            }
        }
        .fullScreenCover(isPresented: $syncCoordinator.isShowingInitialSyncSetup) {
            InitialSyncSetupPage {
                syncCoordinator.completeInitialSyncSetupFlow()
            }
            .environmentObject(profileStore)
            .environmentObject(syncSettingsStore)
            .environmentObject(draftBookkeepingStore)
            .environmentObject(syncCoordinator)
        }
        .onDisappear {
            launchLoadingDelayTask?.cancel()
            launchLoadingDelayTask = nil
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

    private func updateLaunchLoadingVisibility(isRunning: Bool) {
        launchLoadingDelayTask?.cancel()

        guard isRunning else {
            launchLoadingDelayTask = nil
            withAnimation(.easeInOut(duration: 0.18)) {
                isShowingLaunchLoading = false
            }
            return
        }

        launchLoadingDelayTask = Task {
            try? await Task.sleep(nanoseconds: 600_000_000)
            guard !Task.isCancelled else { return }

            await MainActor.run {
                guard syncCoordinator.isRunningLaunchImport else { return }
                withAnimation(.easeInOut(duration: 0.22)) {
                    isShowingLaunchLoading = true
                }
            }
        }
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
        .environmentObject(AIModelSettingsStore())
        .environmentObject(DraftBookkeepingStore())
        .environmentObject(SyncCoordinator())
        .environmentObject(HomeScreenQuickActionRouter.shared)
}
