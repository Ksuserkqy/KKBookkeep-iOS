import SwiftUI

struct SponsorPage: View {
    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 0) {
                NavigationLink {
                    SponsorQRCodePage(method: .wechat)
                } label: {
                    SponsorMethodRow(method: .wechat)
                }

                Divider()

                NavigationLink {
                    SponsorQRCodePage(method: .alipay)
                } label: {
                    SponsorMethodRow(method: .alipay)
                }
            }
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            Spacer()
        }
        .padding(24)
        .padding(.top, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
        .navigationTitle(Text("sponsor.title"))
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                AppBackButton()
            }
        }
    }
}

private struct SponsorMethodRow: View {
    let method: SponsorMethod

    var body: some View {
        HStack(spacing: 12) {
            FontAwesomeIcon(name: method.iconName, size: 20)
                .foregroundStyle(method.brandColor)
                .frame(width: 24)

            Text(method.titleKey)
                .foregroundStyle(.primary)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding()
    }
}

private struct SponsorQRCodePage: View {
    let method: SponsorMethod

    var body: some View {
        VStack(spacing: 24) {
            AsyncImage(url: method.qrCodeURL) { phase in
                switch phase {
                case .empty:
                    ProgressView()
                        .frame(width: 260, height: 260)
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 320)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                case .failure:
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text("sponsor.qrCode.loadFailed")
                            .foregroundStyle(.secondary)
                    }
                    .frame(width: 260, height: 260)
                @unknown default:
                    EmptyView()
                }
            }
            .padding(16)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

            Text(method.instructionKey)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .padding(24)
        .padding(.top, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
        .navigationTitle(Text(method.titleKey))
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                AppBackButton()
            }
        }
    }
}

private enum SponsorMethod {
    case wechat
    case alipay

    var titleKey: LocalizedStringKey {
        switch self {
        case .wechat:
            return "sponsor.wechat"
        case .alipay:
            return "sponsor.alipay"
        }
    }

    var iconName: String {
        switch self {
        case .wechat:
            return "weixin"
        case .alipay:
            return "alipay"
        }
    }

    var brandColor: Color {
        switch self {
        case .wechat:
            return Color(hex: "#07C160")
        case .alipay:
            return Color(hex: "#1677FF")
        }
    }

    var instructionKey: LocalizedStringKey {
        switch self {
        case .wechat:
            return "sponsor.wechat.instruction"
        case .alipay:
            return "sponsor.alipay.instruction"
        }
    }

    var qrCodeURL: URL {
        switch self {
        case .wechat:
            return URL(string: "https://static.ksuser.cn/payment/wechat.png")!
        case .alipay:
            return URL(string: "https://static.ksuser.cn/payment/alipay.jpg")!
        }
    }
}
