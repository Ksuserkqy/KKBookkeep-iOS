import SwiftUI

struct AppLaunchLoadingView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isAnimating = false

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            VStack(spacing: 28) {
                ZStack {
                    loadingRing

                    AppIconView(cornerRadius: 28, shadowRadius: 18, shadowYOffset: 8)
                        .frame(width: 104, height: 104)
                        .scaleEffect(reduceMotion ? 1 : (isAnimating ? 1.04 : 0.98))
                        .animation(
                            reduceMotion ? nil : .easeInOut(duration: 1.15).repeatForever(autoreverses: true),
                            value: isAnimating
                        )
                }
                .frame(width: 184, height: 184)
                .accessibilityHidden(true)

                VStack(spacing: 10) {
                    Text("app.name")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.primary)

                    Text("launch.loading.subtitle")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .multilineTextAlignment(.center)

                ProgressView()
                    .tint(.accentColor)
                    .controlSize(.regular)
                    .accessibilityLabel(Text("launch.loading.subtitle"))
            }
            .padding(32)
        }
        .onAppear {
            isAnimating = true
        }
    }

    private var loadingRing: some View {
        ZStack {
            ForEach(0..<10, id: \.self) { index in
                Capsule(style: .continuous)
                    .fill(Color.accentColor.opacity(0.28 + Double(index) * 0.035))
                    .frame(width: 8, height: 18)
                    .offset(y: -78)
                    .rotationEffect(.degrees(Double(index) * 36))
            }
        }
        .rotationEffect(reduceMotion ? .zero : .degrees(isAnimating ? 360 : 0))
        .animation(
            reduceMotion ? nil : .linear(duration: 1.35).repeatForever(autoreverses: false),
            value: isAnimating
        )
    }
}

#Preview {
    AppLaunchLoadingView()
}
