import SwiftUI

struct ProfilePage: View {
    @EnvironmentObject private var profileStore: ProfileStore

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 14) {
                        ProfileAvatarView(
                            imageDataBase64: profileStore.profile.avatarImageDataBase64,
                            size: 58
                        )

                        VStack(alignment: .leading, spacing: 6) {
                            if profileStore.profile.displayName.isEmpty {
                                Text("profile.displayName.placeholder")
                            } else {
                                Text(profileStore.profile.displayName)
                            }

                            if profileStore.profile.email.isEmpty {
                                Text("profile.placeholder")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            } else {
                                Text(profileStore.profile.email)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                        }
                        .font(.headline)

                        Spacer()
                    }
                    .padding(.vertical, 8)
                }

                if let messageKey = profileStore.messageKey {
                    Section {
                        Text(LocalizedStringKey(messageKey))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
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
