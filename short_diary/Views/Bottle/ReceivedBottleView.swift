//
//  ReceivedBottleView.swift
//  short_diary
//

import SwiftUI

struct ReceivedBottleView: View {
    let bottle: ReceivedBottle
    let onKeep: () -> Void
    let onRelease: () -> Void
    let onReport: () async -> Void
    let onBlock: () async -> Void
    let onFinish: () -> Void
    @State private var isOpen = false
    @State private var safetyMessage: String?
    @State private var followUpPrompt: SafetyFollowUpPrompt?
    @State private var isHandlingSafetyAction = false

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            VStack(spacing: 18) {
                Spacer()

                ZStack {
                    BottleSilhouette()
                        .fill(bottle.bottleColor.gradient)
                        .frame(width: 62, height: 96)
                        .rotationEffect(.degrees(-7))
                        .shadow(color: Color.ink.opacity(0.14), radius: 12, x: 0, y: 8)

                    Image(systemName: "water.waves")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Color.paper.opacity(0.9))
                        .offset(y: 18)
                }
                .symbolEffect(.bounce, value: isOpen)

                Text("どこかのボトルが、流れ着きました。")
                    .font(.system(.headline, design: .serif, weight: .semibold))
                    .foregroundStyle(Color.ink)
                    .multilineTextAlignment(.center)

                Text(bottle.text)
                    .font(.system(size: 22, weight: .regular, design: .serif))
                    .foregroundStyle(Color.ink)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(22)
                    .frame(maxWidth: .infinity)
                    .background(.white.opacity(0.88), in: RoundedRectangle(cornerRadius: 8))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(AppTheme.line)
                    }
                    .opacity(isOpen ? 1 : 0)
                    .offset(y: isOpen ? 0 : 14)

                HStack(spacing: 10) {
                    Button(action: onKeep) {
                        Label("拾っておく", systemImage: "bookmark")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(ReactionButtonStyle(isSelected: true))

                    Button {
                        onRelease()
                    } label: {
                        Label("海に返す", systemImage: "water.waves")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(ReactionButtonStyle(isSelected: false))
                }

                HStack(spacing: 18) {
                    Button(role: .destructive) {
                        followUpPrompt = .confirmReport
                    } label: {
                        Label("通報する", systemImage: "exclamationmark.triangle")
                            .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.cedar.opacity(0.82))
                    .disabled(isHandlingSafetyAction)

                    Button(role: .destructive) {
                        followUpPrompt = .confirmBlock
                    } label: {
                        Label("送信者をブロック", systemImage: "hand.raised")
                            .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.cedar.opacity(0.82))
                    .disabled(isHandlingSafetyAction)
                }
                .padding(.top, 2)

                Spacer()
            }
            .padding(22)

            if let safetyMessage {
                SafetyCompletionOverlay(message: safetyMessage)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                .zIndex(1)
            }

            if let followUpPrompt {
                SafetyFollowUpOverlay(
                    prompt: followUpPrompt,
                    isWorking: isHandlingSafetyAction,
                    onConfirm: {
                        handleFollowUpConfirmation(followUpPrompt)
                    },
                    onCancel: {
                        self.followUpPrompt = nil
                        if followUpPrompt.shouldFinishOnCancel {
                            finishAfterShortDelay()
                        }
                    }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
                .zIndex(2)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6).delay(0.2)) {
                isOpen = true
            }
        }
    }

    private func handleFollowUpConfirmation(_ prompt: SafetyFollowUpPrompt) {
        guard !isHandlingSafetyAction else { return }

        Task {
            followUpPrompt = nil
            switch prompt {
            case .confirmReport:
                await runSafetyAction(message: "通報しました。このボトルは表示されなくなります。") {
                    await onReport()
                }
                followUpPrompt = .blockAfterReport
                return
            case .confirmBlock:
                await runSafetyAction(message: "ブロックしました。この送信者のボトルは今後届きません。") {
                    await onBlock()
                }
                followUpPrompt = .reportAfterBlock
                return
            case .blockAfterReport:
                await runSafetyAction(message: "ブロックしました。この送信者のボトルは今後届きません。") {
                    await onBlock()
                }
            case .reportAfterBlock:
                await runSafetyAction(message: "通報しました。このボトルは表示されなくなります。") {
                    await onReport()
                }
            }
            finishAfterShortDelay()
        }
    }

    private func runSafetyAction(message: String, action: () async -> Void) async {
        isHandlingSafetyAction = true
        await action()
        withAnimation(.easeOut(duration: 0.2)) {
            safetyMessage = message
        }
        isHandlingSafetyAction = false
    }

    private func finishAfterShortDelay() {
        Task {
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            await MainActor.run {
                onFinish()
            }
        }
    }
}

private struct SafetyCompletionOverlay: View {
    let message: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.moss)

            Text(message)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.ink)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .frame(maxWidth: 260)
        .background(Color.paper, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(AppTheme.line)
        }
        .shadow(color: Color.ink.opacity(0.14), radius: 18, x: 0, y: 10)
        .padding(24)
    }
}

private enum SafetyFollowUpPrompt {
    case confirmReport
    case confirmBlock
    case blockAfterReport
    case reportAfterBlock

    var title: String {
        switch self {
        case .confirmReport:
            return "このボトルを通報しますか？"
        case .confirmBlock:
            return "送信者をブロックしますか？"
        case .blockAfterReport:
            return "送信者もブロックしますか？"
        case .reportAfterBlock:
            return "このボトルも通報しますか？"
        }
    }

    var message: String {
        switch self {
        case .confirmReport:
            return "通報すると、このボトルは自分の画面から消え、開発者が確認できる記録として送信されます。"
        case .confirmBlock:
            return "ブロックすると、この送信者のボトルは今後届かなくなります。"
        case .blockAfterReport:
            return "ブロックすると、この送信者のボトルは今後届かなくなります。"
        case .reportAfterBlock:
            return "通報すると、開発者が内容を確認できる記録として送信されます。"
        }
    }

    var confirmTitle: String {
        switch self {
        case .confirmReport:
            return "通報する"
        case .confirmBlock:
            return "ブロックする"
        case .blockAfterReport:
            return "ブロックする"
        case .reportAfterBlock:
            return "通報する"
        }
    }

    var confirmIcon: String {
        switch self {
        case .confirmReport:
            return "exclamationmark.triangle"
        case .confirmBlock:
            return "hand.raised"
        case .blockAfterReport:
            return "hand.raised"
        case .reportAfterBlock:
            return "exclamationmark.triangle"
        }
    }

    var shouldFinishOnCancel: Bool {
        switch self {
        case .confirmReport, .confirmBlock:
            return false
        case .blockAfterReport, .reportAfterBlock:
            return true
        }
    }
}

private struct SafetyFollowUpOverlay: View {
    let prompt: SafetyFollowUpPrompt
    let isWorking: Bool
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        ZStack {
            Color.ink.opacity(0.26)
                .ignoresSafeArea()

            VStack(spacing: 12) {
                Image(systemName: prompt.confirmIcon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Color.cedar)

                VStack(spacing: 5) {
                    Text(prompt.title)
                        .font(.system(size: 18, weight: .semibold, design: .serif))
                        .foregroundStyle(Color.ink)
                        .multilineTextAlignment(.center)

                    Text(prompt.message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(spacing: 8) {
                    Button(role: .destructive, action: onConfirm) {
                        Label(prompt.confirmTitle, systemImage: prompt.confirmIcon)
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                    }
                    .buttonStyle(ReactionButtonStyle(isSelected: false))
                    .disabled(isWorking)

                    Button(action: onCancel) {
                        Text("閉じる")
                            .font(.caption.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                    }
                    .buttonStyle(.bordered)
                    .tint(.ink)
                    .disabled(isWorking)
                }
            }
            .padding(18)
            .frame(maxWidth: 286)
            .background(Color.paper, in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(AppTheme.line)
            }
            .shadow(color: Color.ink.opacity(0.18), radius: 24, x: 0, y: 14)
            .padding(24)
        }
    }
}
