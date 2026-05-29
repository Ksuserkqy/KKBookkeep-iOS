//
//  ContentView.swift
//  KsuserBookKeepingIOS
//
//  Created by Ksuserkqy on 2026/5/29.
//

import SwiftUI

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("app.language") private var language = AppLanguage.system.rawValue
    @AppStorage("app.theme") private var theme = AppTheme.system.rawValue
    @StateObject private var appLock = AppLockManager()
    @State private var isPrivacyCovered = false

    private var activeLocaleIdentifier: String {
        AppLanguage(rawValue: language)?.localeIdentifier ?? Locale.current.identifier
    }

    var body: some View {
        ZStack {
            TabView {
                DashboardPage()
                .tabItem {
                    Label("tab.dashboard", systemImage: "house.fill")
                }

                TransactionsPage()
                .tabItem {
                    Label("tab.transactions", systemImage: "list.bullet.rectangle")
                }

                RecordPage()
                .tabItem {
                    Label("tab.record", systemImage: "plus.circle.fill")
                }

                ReportsPage()
                .tabItem {
                    Label("tab.reports", systemImage: "chart.pie.fill")
                }

                ProfilePage()
                .tabItem {
                    Label("tab.profile", systemImage: "person.crop.circle")
                }
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
        .id(activeLocaleIdentifier)
        .tint(.accentColor)
        .environment(\.locale, Locale(identifier: activeLocaleIdentifier))
        .environmentObject(appLock)
        .preferredColorScheme(AppTheme(rawValue: theme)?.colorScheme)
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                isPrivacyCovered = false
                appLock.refreshConfiguration()
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
}

#Preview {
    ContentView()
}
