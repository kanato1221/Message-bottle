import SwiftUI
import UIKit

struct OnboardingView: View {
    let onFinish: () -> Void

    @State private var selectedPage = 0

    private let pages = [
        OnboardingPage(
            imageName: "onboarding_flow",
            message: "60文字までの短い言葉を、\nボトルに入れて海へ流せます。"
        ),
        OnboardingPage(
            imageName: "onboarding_receive",
            message: "ボトルを流すと、海の向こうから\n誰かのボトルが届くことがあります。"
        ),
        OnboardingPage(
            imageName: "onboarding_shelf",
            message: "手元に残した手紙と、自分が流した言葉は、\nボトル棚で読み返せます。"
        )
    ]

    var body: some View {
        ZStack {
            AppTheme.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button("スキップ", action: onFinish)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)

                TabView(selection: $selectedPage) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                        OnboardingPageView(page: page)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                HStack(spacing: 8) {
                    ForEach(pages.indices, id: \.self) { index in
                        Capsule()
                            .fill(index == selectedPage ? Color.moss : AppTheme.line)
                            .frame(width: index == selectedPage ? 22 : 8, height: 8)
                            .animation(.easeOut(duration: 0.2), value: selectedPage)
                    }
                }
                .padding(.bottom, 24)

                Button {
                    if selectedPage == pages.count - 1 {
                        onFinish()
                    } else {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            selectedPage += 1
                        }
                    }
                } label: {
                    Text(selectedPage == pages.count - 1 ? "海へ行く" : "次へ")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
            }
        }
    }
}

private struct OnboardingPage {
    let imageName: String
    let message: String
}

private struct OnboardingPageView: View {
    let page: OnboardingPage

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 12)

            if let screenshot {
                Image(uiImage: screenshot)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .overlay {
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(AppTheme.line.opacity(0.7))
                    }
                    .shadow(color: Color.ink.opacity(0.1), radius: 16, x: 0, y: 8)
                    .frame(height: 500)
                    .padding(.horizontal, 18)
                    .padding(.bottom, 24)
            }

            VStack(spacing: 18) {
                Text(page.message)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(5)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 28)

            Spacer(minLength: 12)
        }
    }

    private var screenshot: UIImage? {
        let url = Bundle.main.url(
            forResource: page.imageName,
            withExtension: "png",
            subdirectory: "Onboarding"
        ) ?? Bundle.main.url(forResource: page.imageName, withExtension: "png")

        guard let url else { return nil }
        return UIImage(contentsOfFile: url.path)
    }
}
