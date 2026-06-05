import SwiftUI

struct LegalInfoPage: View {
    @State private var safariPage: SafariPage?

    private let userAgreementURL = URL(string: "https://www.ksuser.cn/agreement/user.html")!
    private let privacyPolicyURL = URL(string: "https://www.ksuser.cn/agreement/privacy.html")!
    private let thirdPartySharingURL = URL(string: "https://www.ksuser.cn/agreement/third-party-information-sharing.html")!

    var body: some View {
        List {
            Button {
                safariPage = SafariPage(url: userAgreementURL)
            } label: {
                Label("legal.userAgreement", systemImage: "doc.plaintext")
            }
            .foregroundStyle(.primary)

            Button {
                safariPage = SafariPage(url: privacyPolicyURL)
            } label: {
                Label("legal.privacyPolicy", systemImage: "lock.shield")
            }
            .foregroundStyle(.primary)

            Button {
                safariPage = SafariPage(url: thirdPartySharingURL)
            } label: {
                Label("legal.thirdPartySharing", systemImage: "person.2.badge.gearshape")
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
