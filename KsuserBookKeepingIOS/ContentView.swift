//
//  ContentView.swift
//  KsuserBookKeepingIOS
//
//  Created by Ksuserkqy on 2026/5/29.
//

import SwiftUI

struct ContentView: View {
    @AppStorage("app.language") private var language = AppLanguage.system.rawValue
    @AppStorage("app.theme") private var theme = AppTheme.system.rawValue

    var body: some View {
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
        .tint(.accentColor)
        .environment(\.locale, Locale(identifier: AppLanguage(rawValue: language)?.localeIdentifier ?? Locale.current.identifier))
        .preferredColorScheme(AppTheme(rawValue: theme)?.colorScheme)
    }
}

#Preview {
    ContentView()
}
