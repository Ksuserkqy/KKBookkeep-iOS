import SwiftUI

struct SyncSettingsPage: View {
    @State private var backupEnabled = false
    @State private var provider = SyncProvider.iCloudDrive
    @State private var webDAVAuthentication = WebDAVAuthentication.password
    @State private var serverURL = ""
    @State private var username = ""
    @State private var password = ""
    @State private var accessToken = ""
    @State private var backupOnChange = true
    @State private var autoImport = true
    @State private var backupInterval = BackupInterval.tenMinutes
    @State private var encryptionEnabled = true
    @State private var encryptionPassword = ""
    @State private var encryptionPasswordConfirmation = ""

    var body: some View {
        Form {
            Section {
                LabeledContent("sync.status") {
                    Text("sync.status.localOnly")
                        .foregroundStyle(.secondary)
                }

                LabeledContent("sync.lastSync") {
                    Text("sync.lastSync.never")
                        .foregroundStyle(.secondary)
                }

                LabeledContent("sync.conflictHandling") {
                    Text("sync.conflictHandling.automatic")
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("sync.section.status")
            }

            Section {
                Toggle("sync.backupEnabled", isOn: $backupEnabled)

                Picker("sync.provider", selection: $provider) {
                    ForEach(SyncProvider.allCases) { option in
                        Text(option.titleKey).tag(option)
                    }
                }
            } header: {
                Text("sync.section.provider")
            }

            if provider == .webDAV {
                Section {
                    TextField("sync.webDAV.server.placeholder", text: $serverURL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    Picker("sync.webDAV.authentication", selection: $webDAVAuthentication) {
                        ForEach(WebDAVAuthentication.allCases) { option in
                            Text(option.titleKey).tag(option)
                        }
                    }

                    if webDAVAuthentication == .password {
                        TextField("sync.webDAV.username.placeholder", text: $username)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()

                        SecureField("sync.webDAV.password.placeholder", text: $password)
                    } else {
                        SecureField("sync.webDAV.token.placeholder", text: $accessToken)
                    }
                } header: {
                    Text("sync.section.webDAV")
                } footer: {
                    Text("sync.webDAV.footer")
                }
            }

            Section {
                Toggle("sync.backupOnChange", isOn: $backupOnChange)
                Toggle("sync.autoImport", isOn: $autoImport)

                Picker("sync.backupInterval", selection: $backupInterval) {
                    ForEach(BackupInterval.allCases) { option in
                        Text(option.titleKey).tag(option)
                    }
                }
            } header: {
                Text("sync.section.behavior")
            } footer: {
                Text("sync.behavior.footer")
            }

            Section {
                Toggle("sync.encryption.enabled", isOn: $encryptionEnabled)

                SecureField("sync.encryption.password.placeholder", text: $encryptionPassword)

                SecureField("sync.encryption.confirm.placeholder", text: $encryptionPasswordConfirmation)

                LabeledContent("sync.encryption.algorithm") {
                    Text("sync.encryption.algorithm.aesGCM")
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("sync.section.encryption")
            } footer: {
                Text("sync.encryption.footer")
            }

            Section {
                Button("sync.action.testConnection") {}
                    .disabled(true)

                Button("sync.action.backupNow") {}
                    .disabled(true)

                Button("sync.action.importNow") {}
                    .disabled(true)
            }
        }
        .navigationTitle(Text("sync.title"))
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                AppBackButton()
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button("common.save") {}
                    .disabled(true)
            }
        }
    }
}

private enum SyncProvider: String, CaseIterable, Identifiable {
    case iCloudDrive
    case webDAV

    var id: String { rawValue }

    var titleKey: LocalizedStringKey {
        switch self {
        case .iCloudDrive:
            return "sync.provider.iCloudDrive"
        case .webDAV:
            return "sync.provider.webDAV"
        }
    }
}

private enum WebDAVAuthentication: String, CaseIterable, Identifiable {
    case password
    case token

    var id: String { rawValue }

    var titleKey: LocalizedStringKey {
        switch self {
        case .password:
            return "sync.webDAV.authentication.password"
        case .token:
            return "sync.webDAV.authentication.token"
        }
    }
}

private enum BackupInterval: String, CaseIterable, Identifiable {
    case oneMinute
    case fiveMinutes
    case tenMinutes

    var id: String { rawValue }

    var titleKey: LocalizedStringKey {
        switch self {
        case .oneMinute:
            return "sync.backupInterval.oneMinute"
        case .fiveMinutes:
            return "sync.backupInterval.fiveMinutes"
        case .tenMinutes:
            return "sync.backupInterval.tenMinutes"
        }
    }
}
