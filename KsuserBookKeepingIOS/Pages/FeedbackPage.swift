import SwiftUI

struct FeedbackPage: View {
    private let feedbackEmailURL = URL(string: "mailto:2765301200@qq.com")!
    private let githubIssuesURL = URL(string: "https://github.com/Ksuserkqy/KKBookkeep-iOS/issues")!

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Text("feedback.message")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                VStack(spacing: 0) {
                    Link(destination: feedbackEmailURL) {
                        HStack {
                            Label("feedback.email", systemImage: "envelope.fill")
                            Spacer()
                            Text("2765301200@qq.com")
                                .foregroundStyle(.secondary)
                            Image(systemName: "arrow.up.right")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .padding()
                    }

                    Divider()

                    Link(destination: githubIssuesURL) {
                        HStack {
                            Label("feedback.githubIssue", systemImage: "exclamationmark.bubble.fill")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .padding()
                    }
                }
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .padding(24)
            .padding(.top, 8)
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
        .navigationTitle(Text("feedback.title"))
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                AppBackButton()
            }
        }
    }
}
