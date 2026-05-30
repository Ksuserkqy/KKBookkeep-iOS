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
    @StateObject private var draftBookkeepingStore = DraftBookkeepingStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(profileStore)
                .environmentObject(syncSettingsStore)
                .environmentObject(draftBookkeepingStore)
        }
    }
}
