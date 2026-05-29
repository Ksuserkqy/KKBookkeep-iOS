import SwiftUI

struct ProfilePage: View {
    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(Color.accentColor.opacity(0.16))
                                .frame(width: 58, height: 58)

                            Image(systemName: "person.crop.circle.fill")
                                .font(.system(size: 42))
                                .foregroundStyle(.tint)
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("profile.displayName.placeholder")
                                .font(.headline)

                            Text("profile.placeholder")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }

                        Spacer()
                    }
                    .padding(.vertical, 8)
                }

                Section {
                    NavigationLink {
                        ProfileEditPage()
                    } label: {
                        Label("profile.edit", systemImage: "person.text.rectangle.fill")
                    }

                    NavigationLink {
                        SyncSettingsPage()
                    } label: {
                        Label("profile.sync", systemImage: "arrow.triangle.2.circlepath")
                    }
                } header: {
                    Text("profile.section.account")
                }

                Section {
                    NavigationLink {
                        AppSettingsPage()
                    } label: {
                        Label("profile.settings", systemImage: "gearshape.fill")
                    }

                    NavigationLink {
                        AboutPage()
                    } label: {
                        Label("profile.about", systemImage: "info.circle.fill")
                    }
                } header: {
                    Text("profile.section.app")
                }
            }
            .navigationTitle(Text("tab.profile"))
        }
    }
}
