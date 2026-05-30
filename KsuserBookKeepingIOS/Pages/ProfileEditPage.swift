import PhotosUI
import SwiftUI
import UIKit

struct ProfileEditPage: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var profileStore: ProfileStore
    @EnvironmentObject private var syncSettingsStore: SyncSettingsStore

    @State private var displayName = ""
    @State private var email = ""
    @State private var avatarImageDataBase64: String?
    @State private var currency = ProfileCurrency.cny
    @State private var timeZone = ProfileTimeZone.shanghai
    @State private var note = ""
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var isSaving = false

    var body: some View {
        Form {
            Section {
                VStack(spacing: 12) {
                    ProfileAvatarView(imageDataBase64: avatarImageDataBase64, size: 86)

                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        Text("profile.edit.avatar")
                    }
                    .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }

            Section {
                TextField("profile.edit.displayName.placeholder", text: $displayName)
                    .textContentType(.name)

                TextField("profile.edit.email.placeholder", text: $email)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            } header: {
                Text("profile.edit.section.basic")
            }

            Section {
                Picker("profile.edit.currency", selection: $currency) {
                    ForEach(ProfileCurrency.allCases) { option in
                        Text(option.titleKey).tag(option)
                    }
                }

                Picker("profile.edit.timeZone", selection: $timeZone) {
                    ForEach(ProfileTimeZone.allCases) { option in
                        Text(option.titleKey).tag(option)
                    }
                }
            } header: {
                Text("profile.edit.section.preferences")
            }

            Section {
                TextField("profile.edit.note.placeholder", text: $note, axis: .vertical)
                    .lineLimit(3...6)
            } header: {
                Text("profile.edit.section.note")
            }

            if let messageKey = profileStore.messageKey {
                Section {
                    Text(LocalizedStringKey(messageKey))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(Text("profile.edit.title"))
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                AppBackButton()
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task {
                        await saveProfile()
                    }
                } label: {
                    if isSaving {
                        ProgressView()
                    } else {
                        Text("common.save")
                    }
                }
                .disabled(isSaving)
            }
        }
        .task {
            loadProfile()
        }
        .onChange(of: selectedPhotoItem) { _, newItem in
            Task {
                await loadAvatar(from: newItem)
            }
        }
    }

    private func loadProfile() {
        let profile = profileStore.profile
        displayName = profile.displayName
        email = profile.email
        avatarImageDataBase64 = profile.avatarImageDataBase64
        currency = profile.currency
        timeZone = profile.timeZone
        note = profile.note
    }

    private func saveProfile() async {
        isSaving = true
        let configuration = syncSettingsStore.configuration
        let secrets = syncSettingsStore.secrets(for: configuration)

        let didSave = await profileStore.save(
            displayName: displayName,
            email: email,
            avatarImageDataBase64: avatarImageDataBase64,
            currency: currency,
            timeZone: timeZone,
            note: note,
            syncConfiguration: configuration,
            syncSecrets: secrets
        )

        isSaving = false

        if didSave {
            dismiss()
        }
    }

    private func loadAvatar(from item: PhotosPickerItem?) async {
        guard
            let item,
            let data = try? await item.loadTransferable(type: Data.self),
            let image = UIImage(data: data),
            let compressedData = image
                .scaledToFit(maxPixelLength: 512)
                .jpegData(compressionQuality: 0.82)
        else {
            return
        }

        avatarImageDataBase64 = compressedData.base64EncodedString()
    }
}

private extension UIImage {
    func scaledToFit(maxPixelLength: CGFloat) -> UIImage {
        let maxLength = max(size.width, size.height)
        guard maxLength > maxPixelLength else { return self }

        let scale = maxPixelLength / maxLength
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)

        return UIGraphicsImageRenderer(size: newSize).image { _ in
            draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
