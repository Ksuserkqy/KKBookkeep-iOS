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
    @AppStorage("app.language") private var language = AppLanguage.system.rawValue
    @AppStorage("app.theme") private var theme = AppTheme.system.rawValue
    @StateObject private var appLock = AppLockManager()
    @State private var isPrivacyCovered = false
    @State private var isImportingRemoteData = false
    @State private var lastRemoteDataImportAt: Date?
    @State private var isBackingUpMetadata = false
    @State private var hasPendingMetadataBackup = false
    @State private var metadataBackupTask: Task<Void, Never>?
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
            await importRemoteDataIfNeeded(force: true)
        }
        .onReceive(draftBookkeepingStore.$localMetadataChangeToken.dropFirst()) { _ in
            scheduleMetadataBackup()
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                isPrivacyCovered = false
                appLock.refreshConfiguration()
                Task {
                    await importRemoteDataIfNeeded()
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
        lastRemoteDataImportAt = Date()
        isImportingRemoteData = false
    }

    private func scheduleMetadataBackup() {
        let configuration = syncSettingsStore.configuration
        guard configuration.backupEnabled, configuration.backupOnChange else { return }

        guard !isBackingUpMetadata else {
            hasPendingMetadataBackup = true
            return
        }

        metadataBackupTask?.cancel()
        metadataBackupTask = Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard !Task.isCancelled else { return }
            await backupMetadataIfNeeded(configuration: configuration)
        }
    }

    private func backupMetadataIfNeeded(configuration: SyncConfiguration) async {
        guard !isBackingUpMetadata else {
            hasPendingMetadataBackup = true
            return
        }
        guard configuration == syncSettingsStore.configuration else { return }

        isBackingUpMetadata = true
        let didBackup = await draftBookkeepingStore.backupMetadataNow(
            configuration: configuration,
            secrets: syncSettingsStore.secrets(for: configuration)
        )
        if didBackup {
            try? syncSettingsStore.markBackupCompleted()
        }
        isBackingUpMetadata = false

        if hasPendingMetadataBackup {
            hasPendingMetadataBackup = false
            scheduleMetadataBackup()
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
        .environmentObject(DraftBookkeepingStore())
}
