import SwiftUI

struct AppSettingsPage: View {
    @AppStorage("app.language") private var language = AppLanguage.system.rawValue
    @AppStorage("app.theme") private var theme = AppTheme.system.rawValue

    var body: some View {
        Form {
            Section {
                Picker("settings.language", selection: $language) {
                    ForEach(AppLanguage.allCases) { option in
                        Text(option.titleKey).tag(option.rawValue)
                    }
                }
            } footer: {
                Text("settings.language.footer")
            }

            Section {
                Picker("settings.theme", selection: $theme) {
                    ForEach(AppTheme.allCases) { option in
                        Text(option.titleKey).tag(option.rawValue)
                    }
                }
            } footer: {
                Text("settings.theme.footer")
            }
        }
        .navigationTitle("settings.title")
        .navigationBarTitleDisplayMode(.inline)
    }
}
