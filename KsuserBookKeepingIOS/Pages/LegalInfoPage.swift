import SwiftUI

struct LegalInfoPage: View {
    private let userAgreementURL = URL(string: "https://www.ksuser.cn/agreement/user.html")!
    private let privacyPolicyURL = URL(string: "https://www.ksuser.cn/agreement/privacy.html")!
    private let thirdPartySharingURL = URL(string: "https://www.ksuser.cn/agreement/third-party-information-sharing.html")!

    var body: some View {
        List {
            Link(destination: userAgreementURL) {
                Label("legal.userAgreement", systemImage: "doc.plaintext")
            }

            Link(destination: privacyPolicyURL) {
                Label("legal.privacyPolicy", systemImage: "lock.shield")
            }

            Link(destination: thirdPartySharingURL) {
                Label("legal.thirdPartySharing", systemImage: "person.2.badge.gearshape")
            }
        }
        .navigationTitle("legal.title")
        .navigationBarTitleDisplayMode(.inline)
    }
}
