//
//  BottleHomeView.swift
//  short_diary
//

import SwiftUI

private enum BottleAnimationPurpose {
    case drift
    case releaseAlone
}

private enum BottleAnimationStage {
    case drifting
    case interlude
    case arriving
}

struct BottleHomeView: View {
    @ObservedObject var store: BottleStore
    @ObservedObject var authStore: AuthStore
    @AppStorage(AppSettings.bottleColorModeKey) private var bottleColorMode = BottleColorMode.chooseEachTime.rawValue
    @AppStorage(AppSettings.defaultBottleColorKey) private var defaultBottleColor = BottleColor.seaGreen.rawValue
    @State private var text = ""
    @State private var selectedBottleColor = BottleColor.seaGreen
    @State private var receivedBottle: ReceivedBottle?
    @State private var didReleaseAlone = false
    @State private var didHoldBottle = false
    @State private var isShowingUnsafeDraftConfirmation = false
    @State private var bottleToConfirm: BottleMessage?
    @State private var unsafeBottleToConfirm: BottleMessage?
    @State private var isShowingDriftAnimation = false
    @State private var driftingBottleColor = BottleColor.seaGreen
    @State private var animationPurpose = BottleAnimationPurpose.drift
    @State private var animationStage = BottleAnimationStage.drifting
    @State private var animationDidFinish = false
    @State private var driftRequestDidFinish = false
    @State private var pendingReceivedBottle: ReceivedBottle?
    @FocusState private var isComposerFocused: Bool
    private let maxLength = 60

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background
                    .ignoresSafeArea()
                    .onTapGesture {
                        isComposerFocused = false
                    }

                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("言葉を、海へ流す。")
                                .font(.system(.largeTitle, design: .serif, weight: .semibold))
                                .foregroundStyle(Color.ink)

                            Text("60文字まで入力できます。")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)

                            Text(limitStatusText)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color.moss)
                        }
                        .onTapGesture {
                            isComposerFocused = false
                        }

                        if !store.waitingBottles.isEmpty {
                            waitingBottlesSection
                        }

                        BottleComposer(
                            text: $text,
                            selectedBottleColor: $selectedBottleColor,
                            colorMode: currentColorMode,
                            fixedBottleColor: fixedBottleColor,
                            maxLength: maxLength,
                            isFocused: $isComposerFocused
                        )

                        Button {
                            isComposerFocused = false
                            if BottleContentSafety.containsUnsafeContent(text) {
                                withAnimation(.easeOut(duration: 0.2)) {
                                    isShowingUnsafeDraftConfirmation = true
                                }
                            } else {
                                bottleAndShowChoices()
                            }
                        } label: {
                            Label("海に流す", systemImage: "paperplane")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 15)
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(!canBottle)
                        .opacity(canBottle ? 1 : 0.55)

                        if let bottleNotice {
                            Text(bottleNotice)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                                .onTapGesture {
                                    isComposerFocused = false
                                }
                        }

                        if let exchangeErrorMessage = store.exchangeErrorMessage {
                            Text(exchangeErrorMessage)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color.cedar)
                                .fixedSize(horizontal: false, vertical: true)
                                .onTapGesture {
                                    isComposerFocused = false
                                }
                        }

                        if didReleaseAlone {
                            Text("流しました。この言葉は誰にも届きません。")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color.moss)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .onTapGesture {
                                    isComposerFocused = false
                                }
                                .onAppear {
                                    Task {
                                        try? await Task.sleep(nanoseconds: 2_200_000_000)
                                        await MainActor.run {
                                            withAnimation(.easeOut(duration: 0.2)) {
                                                didReleaseAlone = false
                                            }
                                        }
                                    }
                                }
                        }

                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 86)
                    .padding(.bottom, 28)
                }
                .scrollDismissesKeyboard(.interactively)

                if isShowingUnsafeDraftConfirmation {
                    UnsafeDraftConfirmationOverlay(
                        text: text,
                        onRewrite: {
                            withAnimation(.easeOut(duration: 0.2)) {
                                isShowingUnsafeDraftConfirmation = false
                            }
                            isComposerFocused = true
                        },
                        onBottle: {
                            putDraftInBottle()
                            withAnimation(.easeOut(duration: 0.2)) {
                                isShowingUnsafeDraftConfirmation = false
                            }
                        }
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    .zIndex(1)
                }

                if let bottleToConfirm {
                    DriftConfirmationOverlay(
                        bottle: bottleToConfirm,
                        isDailyLimitEnabled: store.isDailyLimitEnabled,
                        remainingDriftsToday: store.remainingDriftsToday,
                        onDrift: {
                            if BottleContentSafety.containsUnsafeContent(bottleToConfirm.text) {
                                withAnimation(.easeOut(duration: 0.2)) {
                                    self.bottleToConfirm = nil
                                    unsafeBottleToConfirm = bottleToConfirm
                                }
                            } else {
                                startDrift(bottleToConfirm)
                            }
                        },
                        onHold: {
                            store.hold(bottleToConfirm)
                            withAnimation(.easeOut(duration: 0.2)) {
                                self.bottleToConfirm = nil
                                didHoldBottle = true
                            }
                        },
                        onReleaseAlone: {
                            startReleaseAlone(bottleToConfirm)
                        }
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    .zIndex(1)
                }

                if let unsafeBottleToConfirm {
                    UnsafeContentConfirmationOverlay(
                        bottle: unsafeBottleToConfirm,
                        onRewrite: {
                            rewrite(unsafeBottleToConfirm)
                        },
                        onRelease: {
                            startReleaseAlone(unsafeBottleToConfirm)
                        }
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    .zIndex(1)
                }

                if didHoldBottle {
                    HoldCompletionOverlay()
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
                        .zIndex(2)
                        .onAppear {
                            Task {
                                try? await Task.sleep(nanoseconds: 2_200_000_000)
                                await MainActor.run {
                                    withAnimation(.easeOut(duration: 0.2)) {
                                        didHoldBottle = false
                                    }
                                }
                            }
                        }
                }

            }
            .navigationTitle("")
            .navigationBarHidden(true)
            .navigationDestination(item: $receivedBottle) { bottle in
                ReceivedBottleView(
                    bottle: bottle,
                    onKeep: {
                        receivedBottle = nil
                    },
                    onRelease: {
                        await store.releaseReceived(bottle, clientID: clientID)
                    },
                    onReport: {
                        await store.reportReceived(bottle, clientID: clientID)
                    },
                    onBlock: {
                        await store.blockSender(of: bottle, clientID: clientID)
                    },
                    onFinish: {
                        receivedBottle = nil
                    }
                )
                .navigationBarBackButtonHidden(true)
            }
            .fullScreenCover(isPresented: $isShowingDriftAnimation) {
                switch animationStage {
                case .drifting:
                    BottleDriftingAnimationView(
                        bottleColor: driftingBottleColor,
                        onFinished: handleBottleAnimationFinished
                    )
                case .interlude:
                    BottleAnimationInterludeView()
                case .arriving:
                    BottleArrivingAnimationView(
                        bottleColor: pendingReceivedBottle?.bottleColor ?? driftingBottleColor,
                        onFinished: finishArrivalAnimation
                    )
                }
            }
        }
    }

    private var waitingBottlesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("手元のボトル")
                .font(.headline)
                .foregroundStyle(Color.ink)

            ForEach(store.waitingBottles) { bottle in
                WaitingBottleCard(
                    bottle: bottle,
                    ignoresDriftDelay: store.isTestMode,
                    canReachOthers: !BottleContentSafety.containsUnsafeContent(bottle.text),
                    onRequestDrift: {
                        isComposerFocused = false
                        withAnimation(.easeOut(duration: 0.2)) {
                            bottleToConfirm = bottle
                        }
                    },
                    onDiscard: {
                        isComposerFocused = false
                        store.discard(bottle)
                    }
                )
                .onTapGesture {
                    isComposerFocused = false
                }
            }
        }
    }

    private var canBottle: Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty
            && trimmed.count <= maxLength
            && store.canCreateBottle
    }

    private var limitStatusText: String {
        guard store.isDailyLimitEnabled else {
            return "実機テスト中のため、今日は本数制限なしで流せます。"
        }
        return "今日、誰かに届けられるボトルはあと\(store.remainingDriftsToday)本です。"
    }

    private var bottleNotice: String? {
        if store.hasWaitingBottle {
            return "手元のボトルを流すか削除すると、次のボトルを入れられます。"
        }
        return nil
    }

    private var currentColorMode: BottleColorMode {
        BottleColorMode.value(for: bottleColorMode)
    }

    private var fixedBottleColor: BottleColor {
        BottleColor(rawValue: defaultBottleColor) ?? .seaGreen
    }

    private var bottleColorForNewMessage: BottleColor {
        currentColorMode == .useDefault ? fixedBottleColor : selectedBottleColor
    }

    private var clientID: String {
        authStore.userID
    }

    private func startDrift(_ bottle: BottleMessage) {
        driftingBottleColor = bottle.bottleColor
        animationPurpose = .drift
        animationStage = .drifting
        animationDidFinish = false
        driftRequestDidFinish = false
        pendingReceivedBottle = nil

        withAnimation(.easeOut(duration: 0.2)) {
            bottleToConfirm = nil
            isShowingDriftAnimation = true
        }

        Task {
            let result = await store.drift(bottle, clientID: clientID)

            await MainActor.run {
                pendingReceivedBottle = result.receivedBottle
                driftRequestDidFinish = true
                if animationDidFinish {
                    finishDriftAnimation()
                }
            }
        }
    }

    private func startReleaseAlone(_ bottle: BottleMessage) {
        driftingBottleColor = bottle.bottleColor
        animationPurpose = .releaseAlone
        animationStage = .drifting
        animationDidFinish = false
        store.releaseAlone(bottle)

        withAnimation(.easeOut(duration: 0.2)) {
            bottleToConfirm = nil
            unsafeBottleToConfirm = nil
            isShowingDriftAnimation = true
        }
    }

    private func handleBottleAnimationFinished() {
        guard !animationDidFinish else { return }
        animationDidFinish = true

        switch animationPurpose {
        case .drift:
            if driftRequestDidFinish {
                finishDriftAnimation()
            }
        case .releaseAlone:
            withAnimation(.easeOut(duration: 0.25)) {
                isShowingDriftAnimation = false
                didReleaseAlone = true
            }
        }
    }

    private func finishDriftAnimation() {
        guard pendingReceivedBottle != nil else {
            withAnimation(.easeOut(duration: 0.25)) {
                isShowingDriftAnimation = false
            }
            return
        }

        animationStage = .interlude
        Task {
            try? await Task.sleep(nanoseconds: 200_000_000)
            guard !Task.isCancelled, isShowingDriftAnimation else { return }
            withAnimation(.easeInOut(duration: 0.3)) {
                animationStage = .arriving
            }
        }
    }

    private func finishArrivalAnimation() {
        withAnimation(.easeOut(duration: 0.25)) {
            isShowingDriftAnimation = false
        }
        receivedBottle = pendingReceivedBottle
        pendingReceivedBottle = nil
    }

    private func putDraftInBottle() {
        store.bottle(text: text, color: bottleColorForNewMessage)
        text = ""
    }

    private func bottleAndShowChoices() {
        guard let bottle = store.bottle(text: text, color: bottleColorForNewMessage) else { return }
        text = ""
        withAnimation(.easeOut(duration: 0.2)) {
            bottleToConfirm = bottle
        }
    }

    private func rewrite(_ bottle: BottleMessage) {
        text = bottle.text
        selectedBottleColor = bottle.bottleColor
        store.discard(bottle)

        withAnimation(.easeOut(duration: 0.2)) {
            unsafeBottleToConfirm = nil
        }
        isComposerFocused = true
    }
}

private struct HoldCompletionOverlay: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.title.weight(.semibold))
                .foregroundStyle(Color.moss)

            Text("保留しました。1時間後に通知します。")
                .font(.headline.weight(.semibold))
                .foregroundStyle(Color.ink)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .frame(maxWidth: 320)
        .background(Color.paper, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(AppTheme.line)
        }
        .shadow(color: Color.ink.opacity(0.14), radius: 18, x: 0, y: 10)
        .padding(24)
    }
}

private struct BottleComposer: View {
    @Binding var text: String
    @Binding var selectedBottleColor: BottleColor
    let colorMode: BottleColorMode
    let fixedBottleColor: BottleColor
    let maxLength: Int
    var isFocused: FocusState<Bool>.Binding

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ZStack(alignment: .topLeading) {
                TextEditor(text: limitedText)
                    .focused(isFocused)
                    .font(.system(.title3, design: .serif))
                    .foregroundStyle(Color.ink)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 150)
                    .padding(12)
                    .background(Color.paper.opacity(0.78), in: RoundedRectangle(cornerRadius: 8))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(AppTheme.line)
                    }
                    .onTapGesture {
                        isFocused.wrappedValue = true
                    }

                if text.isEmpty {
                    Text("ボトルに入れたい言葉を書く")
                        .font(.system(.title3, design: .serif))
                        .foregroundStyle(.secondary.opacity(0.55))
                        .padding(.horizontal, 18)
                        .padding(.vertical, 20)
                    .allowsHitTesting(false)
                }
            }

            if colorMode == .chooseEachTime {
                BottleColorPicker(selectedColor: $selectedBottleColor)
            } else {
                FixedBottleColorNotice(color: fixedBottleColor)
            }

            if remainingCount <= 12 {
                Text("あと \(remainingCount) 文字")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(remainingCount < 0 ? Color.cedar : .secondary)
            }
        }
    }

    private var remainingCount: Int {
        maxLength - text.count
    }

    private var limitedText: Binding<String> {
        Binding(
            get: { text },
            set: { newValue in
                text = String(newValue.prefix(maxLength))
            }
        )
    }
}

private struct FixedBottleColorNotice: View {
    let color: BottleColor

    var body: some View {
        HStack(spacing: 9) {
            Circle()
                .fill(color.gradient)
                .frame(width: 18, height: 18)
                .overlay {
                    Circle()
                        .stroke(AppTheme.line, lineWidth: 1)
                }

            Text("設定の \(color.title) のボトルを使います")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }
}

private struct BottleColorPicker: View {
    @Binding var selectedColor: BottleColor

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("ボトルの色")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                ForEach(BottleColor.allCases) { color in
                    Button {
                        selectedColor = color
                    } label: {
                        VStack(spacing: 6) {
                            Circle()
                                .fill(color.gradient)
                                .frame(width: 34, height: 34)
                                .overlay {
                                    Circle()
                                        .stroke(selectedColor == color ? Color.ink : AppTheme.line, lineWidth: selectedColor == color ? 2 : 1)
                                }
                                .overlay {
                                    if selectedColor == color {
                                        Image(systemName: "checkmark")
                                            .font(.caption.weight(.bold))
                                            .foregroundStyle(Color.paper)
                                    }
                                }

                            Text(color.title)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(selectedColor == color ? Color.ink : .secondary)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(color.title)のボトル")
                }
            }
        }
    }
}

private struct WaitingBottleCard: View {
    let bottle: BottleMessage
    let ignoresDriftDelay: Bool
    let canReachOthers: Bool
    let onRequestDrift: () -> Void
    let onDiscard: () -> Void
    @State private var horizontalOffset: CGFloat = 0
    @State private var isDeleteRevealed = false
    private let deleteWidth: CGFloat = 86

    var body: some View {
        TimelineView(.periodic(from: Date(), by: 30)) { context in
            let isReady = ignoresDriftDelay || context.date >= bottle.availableToDriftAt

            ZStack(alignment: .trailing) {
                Button(role: .destructive, action: onDiscard) {
                    VStack(spacing: 4) {
                        Image(systemName: "trash")
                            .font(.headline)
                        Text("削除")
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(Color.paper)
                    .frame(width: deleteWidth)
                    .frame(maxHeight: .infinity)
                    .background(Color.cedar, in: RoundedRectangle(cornerRadius: 8))
                }

                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Capsule()
                            .fill(bottle.bottleColor.gradient)
                            .frame(width: 28, height: 12)

                        Text("\(bottle.bottleColor.title)のボトル")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }

                    Text(bottle.text)
                        .font(.system(.body, design: .serif))
                        .foregroundStyle(Color.ink)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(isReady ? "流せるようになりました" : "あと \(remainingText(from: context.date)) で流せます")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(isReady ? Color.moss : .secondary)

                    Button {
                        closeDeleteAction()
                        onRequestDrift()
                    } label: {
                        Label(
                            canReachOthers ? "海へ流す" : "誰にも届かない海へ流す",
                            systemImage: "water.waves"
                        )
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(ReactionButtonStyle(isSelected: isReady))
                    .disabled(!isReady)
                }
                .padding(16)
                .background(Color.paper, in: RoundedRectangle(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(AppTheme.line)
                }
                .offset(x: horizontalOffset)
                .gesture(
                    DragGesture(minimumDistance: 16)
                        .onChanged { value in
                            let baseOffset = isDeleteRevealed ? -deleteWidth : 0
                            horizontalOffset = min(0, max(-deleteWidth, baseOffset + value.translation.width))
                        }
                        .onEnded { _ in
                            withAnimation(.easeOut(duration: 0.18)) {
                                isDeleteRevealed = horizontalOffset < -deleteWidth / 2
                                horizontalOffset = isDeleteRevealed ? -deleteWidth : 0
                            }
                        }
                )
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private func closeDeleteAction() {
        guard isDeleteRevealed else { return }
        withAnimation(.easeOut(duration: 0.18)) {
            isDeleteRevealed = false
            horizontalOffset = 0
        }
    }

    private func remainingText(from date: Date) -> String {
        let remaining = max(bottle.availableToDriftAt.timeIntervalSince(date), 0)
        let minutes = Int(ceil(remaining / 60))
        if minutes >= 60 {
            return "約\(minutes / 60)時間"
        }
        return "\(max(minutes, 1))分"
    }

}

private struct UnsafeDraftConfirmationOverlay: View {
    let text: String
    let onRewrite: () -> Void
    let onBottle: () -> Void

    var body: some View {
        ZStack {
            Color.ink.opacity(0.28)
                .ignoresSafeArea()

            VStack(spacing: 18) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.title.weight(.semibold))
                    .foregroundStyle(Color.cedar)

                VStack(spacing: 8) {
                    Text("確認してください")
                        .font(.system(.title3, design: .serif, weight: .semibold))
                        .foregroundStyle(Color.ink)

                    Text("このメッセージには不適切な言葉が含まれています。このボトルは、誰にも届かない海にしか流すことができません。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Text(text)
                    .font(.system(.body, design: .serif))
                    .foregroundStyle(Color.ink)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 8)

                VStack(spacing: 10) {
                    Button(action: onRewrite) {
                        CenteredActionLabel(title: "書き直す", systemImage: "pencil")
                    }
                    .buttonStyle(PrimaryButtonStyle())

                    Button(action: onBottle) {
                        CenteredActionLabel(title: "ボトルに入れる", systemImage: "shippingbox")
                    }
                    .buttonStyle(.bordered)
                    .tint(.moss)
                }
            }
            .padding(22)
            .frame(maxWidth: 330)
            .background(Color.paper, in: RoundedRectangle(cornerRadius: 20))
            .overlay {
                RoundedRectangle(cornerRadius: 20)
                    .stroke(AppTheme.line.opacity(0.8))
            }
            .shadow(color: Color.ink.opacity(0.18), radius: 24, x: 0, y: 14)
            .padding(24)
        }
    }
}

private struct DriftConfirmationOverlay: View {
    let bottle: BottleMessage
    let isDailyLimitEnabled: Bool
    let remainingDriftsToday: Int
    let onDrift: () -> Void
    let onHold: () -> Void
    let onReleaseAlone: () -> Void

    var body: some View {
        ZStack {
            Color.ink.opacity(0.28)
                .ignoresSafeArea()
                .onTapGesture(perform: onHold)

            VStack(spacing: 18) {
                Image(systemName: "water.waves")
                    .font(.title.weight(.semibold))
                    .foregroundStyle(Color.moss)

                VStack(spacing: 8) {
                    Text("本当に流しますか？")
                        .font(.system(.title3, design: .serif, weight: .semibold))
                        .foregroundStyle(Color.ink)

                    Text("これは誰かの元へ届きます。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text(limitText)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(canDrift ? Color.moss : Color.cedar)
                }

                Text(bottle.text)
                    .font(.system(.body, design: .serif))
                    .foregroundStyle(Color.ink)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 8)

                VStack(spacing: 10) {
                    Button(action: onDrift) {
                        CenteredActionLabel(title: "海に流す", systemImage: "paperplane")
                    }
                    .buttonStyle(ConfirmationActionButtonStyle(kind: .primary))
                    .disabled(!canDrift)
                    .opacity(canDrift ? 1 : 0.55)

                    Button(action: onHold) {
                        CenteredActionLabel(title: "保留", systemImage: "shippingbox")
                    }
                    .buttonStyle(ConfirmationActionButtonStyle(kind: .neutral))

                    Button(action: onReleaseAlone) {
                        CenteredActionLabel(title: "誰にも届かない海へ", systemImage: "moon")
                    }
                    .buttonStyle(ConfirmationActionButtonStyle(kind: .accent))
                }
            }
            .padding(22)
            .frame(maxWidth: 330)
            .background(Color.paper, in: RoundedRectangle(cornerRadius: 20))
            .overlay {
                RoundedRectangle(cornerRadius: 20)
                    .stroke(AppTheme.line.opacity(0.8))
            }
            .shadow(color: Color.ink.opacity(0.18), radius: 24, x: 0, y: 14)
            .padding(24)
        }
    }

    private var canDrift: Bool {
        !isDailyLimitEnabled || remainingDriftsToday > 0
    }

    private var limitText: String {
        if !isDailyLimitEnabled {
            return "実機テスト中のため、本数制限は外しています。"
        }
        return remainingDriftsToday > 0 ? "今日はあと\(remainingDriftsToday)本流せます。" : "今日はもう誰かに届く海へは流せません。"
    }
}

private struct UnsafeContentConfirmationOverlay: View {
    let bottle: BottleMessage
    let onRewrite: () -> Void
    let onRelease: () -> Void

    var body: some View {
        ZStack {
            Color.ink.opacity(0.28)
                .ignoresSafeArea()

            VStack(spacing: 18) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.title.weight(.semibold))
                    .foregroundStyle(Color.cedar)

                VStack(spacing: 8) {
                    Text("確認してください")
                        .font(.system(.title3, design: .serif, weight: .semibold))
                        .foregroundStyle(Color.ink)

                    Text("このメッセージには不適切な言葉が含まれているため、誰にも届かない海へ流します。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Text(bottle.text)
                    .font(.system(.body, design: .serif))
                    .foregroundStyle(Color.ink)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 8)

                VStack(spacing: 10) {
                    Button(action: onRewrite) {
                        CenteredActionLabel(title: "書き直す", systemImage: "pencil")
                    }
                    .buttonStyle(PrimaryButtonStyle())

                    Button(action: onRelease) {
                        CenteredActionLabel(title: "流す", systemImage: "water.waves")
                    }
                    .buttonStyle(.bordered)
                    .tint(.moss)
                }
            }
            .padding(22)
            .frame(maxWidth: 330)
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

private struct CenteredActionLabel: View {
    let title: String
    let systemImage: String

    var body: some View {
        ZStack {
            Text(title)
                .font(.headline)
                .multilineTextAlignment(.center)

            HStack {
                Image(systemName: systemImage)
                    .imageScale(.medium)
                    .frame(width: 24)
                Spacer()
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 50)
        .padding(.horizontal, 14)
    }
}

private struct ConfirmationActionButtonStyle: ButtonStyle {
    enum Kind: Equatable {
        case primary
        case neutral
        case accent
    }

    let kind: Kind

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(foregroundColor)
            .background(backgroundColor, in: RoundedRectangle(cornerRadius: 14))
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .stroke(borderColor.opacity(0.82), lineWidth: kind == .primary ? 0 : 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: 14))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.78 : 1)
    }

    private var foregroundColor: Color {
        switch kind {
        case .primary: .paper
        case .neutral: .ink
        case .accent: .moss
        }
    }

    private var backgroundColor: Color {
        kind == .primary ? .ink : .clear
    }

    private var borderColor: Color {
        switch kind {
        case .primary: .clear
        case .neutral: .ink
        case .accent: .moss
        }
    }
}
