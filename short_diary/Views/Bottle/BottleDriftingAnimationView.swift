import AVFoundation
import SwiftUI
import UIKit

struct BottleDriftingAnimationView: View {
    let bottleColor: BottleColor
    let onFinished: () -> Void

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let videoURL = bottleColor.driftingAnimationURL {
                BottleAnimationVideoView(url: videoURL, onFinished: onFinished)
                    .ignoresSafeArea()
                    .accessibilityHidden(true)
            } else {
                Text("ボトルを流しています")
                    .font(.system(.headline, design: .serif, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
    }
}

struct BottleArrivingAnimationView: View {
    let bottleColor: BottleColor
    let onFinished: () -> Void

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let videoURL = bottleColor.arrivingAnimationURL {
                BottleAnimationVideoView(url: videoURL, onFinished: onFinished)
                    .ignoresSafeArea()
                    .accessibilityHidden(true)
            } else if let videoURL = bottleColor.driftingAnimationURL {
                BottleAnimationVideoView(url: videoURL, playsInReverse: true, onFinished: onFinished)
                    .ignoresSafeArea()
                    .accessibilityHidden(true)
            } else {
                Text("ボトルが流れ着いています")
                    .font(.system(.headline, design: .serif, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
    }
}

struct BottleAnimationInterludeView: View {
    var body: some View {
        Color.black.ignoresSafeArea()
    }
}

private extension BottleColor {
    var driftingAnimationFileName: String {
        switch self {
        case .seaGreen: "bottle_animation_green"
        case .amber: "bottle_animation_yellow"
        case .skyBlue: "bottle_animation_blue"
        case .smoke: "bottle_animation_gray"
        case .rose: "bottle_animation_red"
        }
    }

    var driftingAnimationURL: URL? {
        Bundle.main.url(
            forResource: driftingAnimationFileName,
            withExtension: "mp4",
            subdirectory: "BottleAnimations"
        ) ?? Bundle.main.url(forResource: driftingAnimationFileName, withExtension: "mp4")
    }

    var arrivingAnimationURL: URL? {
        let reverseFileName = "\(driftingAnimationFileName)_reverse"
        return Bundle.main.url(
            forResource: reverseFileName,
            withExtension: "mp4",
            subdirectory: "BottleAnimations"
        ) ?? Bundle.main.url(forResource: reverseFileName, withExtension: "mp4")
    }
}

private struct BottleAnimationVideoView: UIViewRepresentable {
    let url: URL
    var playsInReverse = false
    let onFinished: () -> Void

    func makeUIView(context: Context) -> BottleAnimationPlayerView {
        BottleAnimationPlayerView(url: url, playsInReverse: playsInReverse, onFinished: onFinished)
    }

    func updateUIView(_ view: BottleAnimationPlayerView, context: Context) {
        view.onFinished = onFinished
    }

    static func dismantleUIView(_ view: BottleAnimationPlayerView, coordinator: ()) {
        view.stop()
    }
}

private final class BottleAnimationPlayerView: UIView {
    private let player: AVPlayer
    private var endObserver: NSObjectProtocol?
    private var statusObservation: NSKeyValueObservation?
    private var reverseTimeObserver: Any?
    private var didFinish = false
    var onFinished: () -> Void

    override class var layerClass: AnyClass { AVPlayerLayer.self }

    private var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }

    init(url: URL, playsInReverse: Bool, onFinished: @escaping () -> Void) {
        let item = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: item)
        self.onFinished = onFinished
        super.init(frame: .zero)
        backgroundColor = .black
        player.isMuted = true
        playerLayer.player = player
        playerLayer.videoGravity = .resizeAspectFill
        if playsInReverse {
            statusObservation = item.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
                guard item.status == .readyToPlay else { return }
                self?.startReversePlayback(item: item)
            }
        } else {
            endObserver = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: item,
                queue: .main
            ) { [weak self] _ in
                self?.finish()
            }
            player.play()
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func stop() {
        player.pause()
        statusObservation = nil
        if let reverseTimeObserver {
            player.removeTimeObserver(reverseTimeObserver)
            self.reverseTimeObserver = nil
        }
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
            self.endObserver = nil
        }
    }

    deinit {
        if let reverseTimeObserver {
            player.removeTimeObserver(reverseTimeObserver)
        }
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
    }

    private func startReversePlayback(item: AVPlayerItem) {
        statusObservation = nil
        let duration = item.duration
        guard duration.isNumeric, duration.seconds > 0 else {
            finish()
            return
        }
        player.seek(to: duration, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
            guard let self else { return }
            reverseTimeObserver = player.addPeriodicTimeObserver(
                forInterval: CMTime(seconds: 0.03, preferredTimescale: 600),
                queue: .main
            ) { [weak self] time in
                if time.seconds <= 0.04 {
                    self?.finish()
                }
            }
            player.rate = -1
        }
    }

    private func finish() {
        guard !didFinish else { return }
        didFinish = true
        onFinished()
    }
}
