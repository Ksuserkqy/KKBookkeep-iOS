//
//  ContentView.swift
//  KsuserBookKeepingIOS
//
//  Created by Ksuserkqy on 2026/5/29.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            AppTabPage(
                titleKey: "tab.dashboard",
                subtitleKey: "dashboard.placeholder",
                systemImage: "house.fill"
            )
            .tabItem {
                Label("tab.dashboard", systemImage: "house.fill")
            }

            AppTabPage(
                titleKey: "tab.transactions",
                subtitleKey: "transactions.placeholder",
                systemImage: "list.bullet.rectangle"
            )
            .tabItem {
                Label("tab.transactions", systemImage: "list.bullet.rectangle")
            }

            AppTabPage(
                titleKey: "tab.record",
                subtitleKey: "record.placeholder",
                systemImage: "plus.circle.fill"
            )
            .tabItem {
                Label("tab.record", systemImage: "plus.circle.fill")
            }

            AppTabPage(
                titleKey: "tab.reports",
                subtitleKey: "reports.placeholder",
                systemImage: "chart.pie.fill"
            )
            .tabItem {
                Label("tab.reports", systemImage: "chart.pie.fill")
            }

            AppTabPage(
                titleKey: "tab.profile",
                subtitleKey: "profile.placeholder",
                systemImage: "person.crop.circle"
            )
            .tabItem {
                Label("tab.profile", systemImage: "person.crop.circle")
            }
        }
        .tint(.accentColor)
    }
}

private struct AppTabPage: View {
    let titleKey: LocalizedStringKey
    let subtitleKey: LocalizedStringKey
    let systemImage: String

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(systemName: systemImage)
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundStyle(.tint)

                VStack(spacing: 8) {
                    Text(titleKey)
                        .font(.title2.weight(.semibold))

                    Text(subtitleKey)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemGroupedBackground))
            .navigationTitle(titleKey)
        }
    }
}

#Preview {
    ContentView()
}
