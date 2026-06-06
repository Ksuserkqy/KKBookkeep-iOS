import SwiftUI

struct LegalInfoPage: View {
    @Environment(\.locale) private var locale
    @State private var safariPage: SafariPage?

    var body: some View {
        List {
            Button {
                safariPage = SafariPage(url: LegalDocumentLinks.userAgreementURL(for: locale))
            } label: {
                Label("legal.userAgreement", systemImage: "doc.plaintext")
            }
            .foregroundStyle(.primary)

            Button {
                safariPage = SafariPage(url: LegalDocumentLinks.privacyPolicyURL(for: locale))
            } label: {
                Label("legal.privacyPolicy", systemImage: "lock.shield")
            }
            .foregroundStyle(.primary)
        }
        .navigationTitle(Text("legal.title"))
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .sheet(item: $safariPage) { page in
            SafariView(url: page.url)
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                AppBackButton()
            }
        }
    }
}
