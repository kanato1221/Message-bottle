//
//  BottleHomeView.swift
//  short_diary
//

import SwiftUI

struct BottleHomeView: View {
    @ObservedObject var store: BottleStore
    @ObservedObject var authStore: AuthStore
    @AppStorage(AppSettings.bottleColorModeKey) private var bottleColorMode = BottleColorMode.chooseEachTime.rawValue
    @AppStorage(AppSettings.defaultBottleColorKey) private var defaultBottleColor = BottleColor.seaGreen.rawValue
    @State private var text = ""
    @State private var selectedBottleColor = BottleColor.seaGreen
    @State private var receivedBottle: ReceivedBottle?
    @State private var didReleaseAlone = false
    @State private var isShowingUnsafeDraftConfirmation = false
    @State private var bottleToConfirm: BottleMessage?
    @State private var unsafeBottleToConfirm: BottleMessage?
    @State private var isShowingDriftAnimation = false
    @State private var driftingBottleColor = BottleColor.seaGreen
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
                                .font(.system(size: 34, weight: .semibold, design: .serif))
                                .foregroundStyle(Color.ink)

                            Text(store.isTestMode
                                 ? "60文字まで。テストモードでは、すぐに海へ流せます。"
                                 : "60文字まで。ボトルに入れて、1時間後に海へ流せます。")
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
                                putDraftInBottle()
                            }
                        } label: {
                            Label("ボトルに入れる", systemImage: "shippingbox")
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
                            withAnimation(.easeOut(duration: 0.2)) {
                                self.bottleToConfirm = nil
                            }
                        },
                        onReleaseAlone: {
                            store.releaseAlone(bottleToConfirm)
                            withAnimation(.easeOut(duration: 0.2)) {
                                self.bottleToConfirm = nil
                                didReleaseAlone = true
                            }
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
                            store.releaseAlone(unsafeBottleToConfirm)
                            withAnimation(.easeOut(duration: 0.2)) {
                                self.unsafeBottleToConfirm = nil
                                didReleaseAlone = true
                            }
                        }
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    .zIndex(1)
                }

                if isShowingDriftAnimation {
                    BottleDriftingAnimationView(bottleColor: driftingBottleColor)
                        .transition(.opacity)
                        .zIndex(2)
                }
            }
            .navigationTitle("")
            .navigationBarHidden(true)
            .overlay(alignment: .topTrailing) {
                Menu {
                    Text(authStore.email)
                    Button("ログアウト", role: .destructive) {
                        authStore.signOut()
                    }
                } label: {
                    Image(systemName: "person.crop.circle")
                        .font(.title3)
                        .foregroundStyle(Color.ink)
                        .frame(width: 44, height: 44)
                        .background(.white.opacity(0.72), in: Circle())
                }
                .padding(.top, 12)
                .padding(.trailing, 18)
            }
            .navigationDestination(item: $receivedBottle) { bottle in
                ReceivedBottleView(
                    bottle: bottle,
                    onKeep: {
                        receivedBottle = nil
                    },
                    onRelease: {
                        let didRelease = await store.releaseReceived(bottle, clientID: clientID)
                        if didRelease {
                            receivedBottle = nil
                        }
                        return didRelease
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
        return !trimmed.isEmpty && trimmed.count <= maxLength && store.canCreateBottle
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

        withAnimation(.easeOut(duration: 0.2)) {
            bottleToConfirm = nil
            isShowingDriftAnimation = true
        }

        Task {
            async let driftedBottle = store.drift(bottle, clientID: clientID)
            try? await Task.sleep(nanoseconds: 2_200_000_000)
            let result = await driftedBottle

            await MainActor.run {
                withAnimation(.easeOut(duration: 0.25)) {
                    isShowingDriftAnimation = false
                }
                receivedBottle = result.receivedBottle
            }
        }
    }

    private func putDraftInBottle() {
        store.bottle(text: text, color: bottleColorForNewMessage)
        text = ""
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
                    .font(.system(size: 20, weight: .regular, design: .serif))
                    .foregroundStyle(Color.ink)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 150)
                    .padding(12)
                    .background(.white.opacity(0.78), in: RoundedRectangle(cornerRadius: 8))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(AppTheme.line)
                    }
                    .onTapGesture {
                        isFocused.wrappedValue = true
                    }

                if text.isEmpty {
                    Text("ボトルに入れたい言葉を書く")
                        .font(.system(size: 20, weight: .regular, design: .serif))
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
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(Color.cedar)

                VStack(spacing: 8) {
                    Text("確認してください")
                        .font(.system(size: 22, weight: .semibold, design: .serif))
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
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(Color.moss)

                VStack(spacing: 8) {
                    Text("本当に流しますか？")
                        .font(.system(size: 22, weight: .semibold, design: .serif))
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
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(!canDrift)
                    .opacity(canDrift ? 1 : 0.55)

                    Button(action: onHold) {
                        CenteredActionLabel(title: "保留", systemImage: "shippingbox")
                    }
                    .buttonStyle(.bordered)
                    .tint(.ink)

                    Button(action: onReleaseAlone) {
                        CenteredActionLabel(title: "誰にも届かない海へ", systemImage: "moon")
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
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(Color.cedar)

                VStack(spacing: 8) {
                    Text("確認してください")
                        .font(.system(size: 22, weight: .semibold, design: .serif))
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
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .imageScale(.medium)

            Text(title)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }
}
