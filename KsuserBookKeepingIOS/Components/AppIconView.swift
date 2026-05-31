import SwiftUI
import UIKit

struct AppIconView: View {
    var cornerRadius: CGFloat = 20
    var shadowRadius: CGFloat = 12
    var shadowYOffset: CGFloat = 6

    var body: some View {
        Group {
            if let image = Bundle.main.primaryAppIcon {
                Image(uiImage: image)
                    .resizable()
            } else {
                Image(systemName: "wallet.pass.fill")
                    .resizable()
                    .scaledToFit()
                    .padding(18)
                    .foregroundStyle(.white)
                    .background(Color.accentColor)
            }
        }
        .scaledToFit()
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: shadowRadius, y: shadowYOffset)
    }
}

private extension Bundle {
    var primaryAppIcon: UIImage? {
        guard
            let icons = infoDictionary?["CFBundleIcons"] as? [String: Any],
            let primaryIcon = icons["CFBundlePrimaryIcon"] as? [String: Any],
            let iconFiles = primaryIcon["CFBundleIconFiles"] as? [String],
            let iconName = iconFiles.last
        else {
            return nil
        }

        return UIImage(named: iconName)
    }
}
