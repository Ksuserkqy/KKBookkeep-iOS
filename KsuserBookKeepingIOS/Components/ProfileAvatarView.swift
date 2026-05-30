import Foundation
import SwiftUI
import UIKit

struct ProfileAvatarView: View {
    let imageDataBase64: String?
    let size: CGFloat

    var body: some View {
        Group {
            if
                let imageDataBase64,
                let data = Data(base64Encoded: imageDataBase64),
                let image = UIImage(data: data)
            {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Circle()
                        .fill(Color.accentColor.opacity(0.16))

                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: size * 0.72))
                        .foregroundStyle(.tint)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
}
