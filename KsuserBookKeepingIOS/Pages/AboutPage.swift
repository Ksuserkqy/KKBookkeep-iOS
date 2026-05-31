import SwiftUI

struct AboutPage: View {
    @Environment(\.locale) private var locale

    private var versionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(version) (\(build))"
    }

    private var shouldShowIcp: Bool {
        let identifier = locale.identifier.lowercased()
        return identifier.hasPrefix("zh-hans")
            || identifier.hasPrefix("zh_hans")
            || identifier.hasPrefix("zh-cn")
            || identifier.hasPrefix("zh_cn")
    }

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                AppIconView()
                    .frame(width: 88, height: 88)

                Text("app.name")
                    .font(.title2.weight(.semibold))
            }

            VStack(spacing: 0) {
                HStack {
                    Label("about.version", systemImage: "number")
                    Spacer()
                    Text(versionText)
                        .foregroundStyle(.secondary)
                }
                .padding()

                Divider()

                NavigationLink {
                    LegalInfoPage()
                } label: {
                    HStack {
                        Label("about.legalInfo", systemImage: "doc.text.fill")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .padding()
                }
            }
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            Spacer()

            VStack(spacing: 8) {
                if shouldShowIcp {
                    Text("about.icp")
                }

                Text("about.copyright")
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
        }
        .padding(24)
        .padding(.top, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
        .navigationTitle(Text("about.title"))
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                AppBackButton()
            }
        }
    }
}
