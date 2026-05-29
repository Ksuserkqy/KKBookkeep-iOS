import SwiftUI

struct AppBackButton: View {
    @Environment(\.dismiss) private var dismiss

    let titleKey: LocalizedStringKey

    init(titleKey: LocalizedStringKey = "common.back") {
        self.titleKey = titleKey
    }

    var body: some View {
        Button {
            dismiss()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.semibold))

                Text(titleKey)
            }
        }
    }
}
