import SwiftUI

struct ProfilePage: View {
    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(.tint)

                        Text("profile.title")
                            .font(.headline)

                        Text("profile.placeholder")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                }

                Section {
                    NavigationLink {
                        AppSettingsPage()
                    } label: {
                        Label("profile.settings", systemImage: "gearshape.fill")
                    }
                }

                Section {
                    NavigationLink {
                        AboutPage()
                    } label: {
                        Label("profile.about", systemImage: "info.circle.fill")
                    }
                }
            }
            .navigationTitle("tab.profile")
        }
    }
}
