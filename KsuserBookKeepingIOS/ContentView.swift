//
//  ContentView.swift
//  KsuserBookKeepingIOS
//
//  Created by Ksuserkqy on 2026/5/29.
//

import SwiftUI

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var profileStore: ProfileStore
    @EnvironmentObject private var syncSettingsStore: SyncSettingsStore
    @AppStorage("app.language") private var language = AppLanguage.system.rawValue
    @AppStorage("app.theme") private var theme = AppTheme.system.rawValue
    @StateObject private var appLock = AppLockManager()
    @State private var isPrivacyCovered = false
    @State private var isImportingProfile = false
    @State private var lastProfileImportAt: Date?
    @State private var selectedTab = AppTab.dashboard

    private var activeLocaleIdentifier: String {
        AppLanguage(rawValue: language)?.localeIdentifier ?? Locale.current.identifier
    }

    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                DashboardPage(selectedTab: $selectedTab)
                .tabItem {
                    Label("tab.dashboard", systemImage: "house.fill")
                }
                .tag(AppTab.dashboard)

                TransactionsPage()
                .tabItem {
                    Label("tab.transactions", systemImage: "list.bullet.rectangle")
                }
                .tag(AppTab.transactions)

                RecordPage(selectedTab: $selectedTab)
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
            await importRemoteProfileIfNeeded(force: true)
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                isPrivacyCovered = false
                appLock.refreshConfiguration()
                Task {
                    await importRemoteProfileIfNeeded()
                }
            case .inactive:
                isPrivacyCovered = appLock.isPasswordEnabled && !appLock.isLocked
            case .background:
                isPrivacyCovered = false
                appLock.lockIfNeeded()
            @unknown default:
                break
            }
        }
    }

    private func importRemoteProfileIfNeeded(force: Bool = false) async {
        let configuration = syncSettingsStore.configuration
        guard configuration.backupEnabled, configuration.autoImport else { return }
        guard !isImportingProfile else { return }

        if
            !force,
            let lastProfileImportAt,
            Date().timeIntervalSince(lastProfileImportAt) < 60
        {
            return
        }

        isImportingProfile = true
        await profileStore.importIfRemoteProfileIsNewer(
            configuration: configuration,
            secrets: syncSettingsStore.secrets(for: configuration)
        )
        lastProfileImportAt = Date()
        isImportingProfile = false
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
}
