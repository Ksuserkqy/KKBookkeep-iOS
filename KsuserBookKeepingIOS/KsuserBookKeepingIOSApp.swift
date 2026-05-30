//
//  KsuserBookKeepingIOSApp.swift
//  KsuserBookKeepingIOS
//
//  Created by Ksuserkqy on 2026/5/29.
//

import SwiftUI

@main
struct KsuserBookKeepingIOSApp: App {
    @StateObject private var profileStore = ProfileStore()
    @StateObject private var syncSettingsStore = SyncSettingsStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(profileStore)
                .environmentObject(syncSettingsStore)
        }
    }
}
