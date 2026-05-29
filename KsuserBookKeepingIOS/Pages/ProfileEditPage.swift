import SwiftUI

struct ProfileEditPage: View {
    @State private var displayName = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var currency = ProfileCurrency.cny
    @State private var timeZone = ProfileTimeZone.shanghai
    @State private var note = ""

    var body: some View {
        Form {
            Section {
                VStack(spacing: 12) {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 76))
                        .foregroundStyle(.tint)

                    Button("profile.edit.avatar") {}
                        .buttonStyle(.bordered)
                        .disabled(true)
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

                TextField("profile.edit.phone.placeholder", text: $phone)
                    .keyboardType(.phonePad)
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
        }
        .navigationTitle(Text("profile.edit.title"))
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

private enum ProfileCurrency: String, CaseIterable, Identifiable {
    case cny
    case usd
    case eur
    case jpy

    var id: String { rawValue }

    var titleKey: LocalizedStringKey {
        switch self {
        case .cny:
            return "profile.edit.currency.cny"
        case .usd:
            return "profile.edit.currency.usd"
        case .eur:
            return "profile.edit.currency.eur"
        case .jpy:
            return "profile.edit.currency.jpy"
        }
    }
}

private enum ProfileTimeZone: String, CaseIterable, Identifiable {
    case shanghai
    case current
    case utc

    var id: String { rawValue }

    var titleKey: LocalizedStringKey {
        switch self {
        case .shanghai:
            return "profile.edit.timeZone.shanghai"
        case .current:
            return "profile.edit.timeZone.current"
        case .utc:
            return "profile.edit.timeZone.utc"
        }
    }
}
