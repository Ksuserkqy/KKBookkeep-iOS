import SwiftUI

struct AboutPage: View {
    @Environment(\.locale) private var locale

    private let repositoryURL = URL(string: "https://github.com/Ksuserkqy/KKBookkeep-iOS/")!

    private var versionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(version) (\(build))"
    }

    private var shouldShowIcp: Bool {
        AppLocalization.isSimplifiedChinese(locale: locale)
    }

    var body: some View {
        ScrollView {
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

                    Divider()

                    NavigationLink {
                        FeedbackPage()
                    } label: {
                        HStack {
                            Label("about.feedback", systemImage: "bubble.left.and.text.bubble.right.fill")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .padding()
                    }

                    Divider()

                    NavigationLink {
                        SponsorPage()
                    } label: {
                        HStack {
                            Label("about.sponsor", systemImage: "heart.fill")
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

                VStack(spacing: 0) {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "chevron.left.forwardslash.chevron.right")
                            .foregroundStyle(.secondary)
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 6) {
                            Text("about.openSource.title")
                                .font(.headline)
                            Text("about.openSource.description")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()
                    }
                    .padding()

                    Divider()

                    Link(destination: repositoryURL) {
                        HStack {
                            Label("about.openSource.repository", systemImage: "link")
                            Spacer()
                            Text("Ksuserkqy/KKBookkeep-iOS")
                                .foregroundStyle(.secondary)
                            Image(systemName: "arrow.up.right")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .padding()
                    }
                }
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

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
            .frame(maxWidth: .infinity)
        }
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
