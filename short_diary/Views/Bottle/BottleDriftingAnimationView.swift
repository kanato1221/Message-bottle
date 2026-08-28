import AVFoundation
import SwiftUI
import UIKit

struct BottleDriftingAnimationView: View {
    let bottleColor: BottleColor

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let videoURL = bottleColor.driftingAnimationURL {
                LoopingVideoView(url: videoURL)
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
}

private struct LoopingVideoView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> LoopingPlayerView {
        LoopingPlayerView(url: url)
    }

    func updateUIView(_ view: LoopingPlayerView, context: Context) {
        view.play(url: url)
    }

    static func dismantleUIView(_ view: LoopingPlayerView, coordinator: ()) {
        view.stop()
    }
}

private final class LoopingPlayerView: UIView {
    private let player = AVQueuePlayer()
    private var playerLooper: AVPlayerLooper?
    private var currentURL: URL?

    override class var layerClass: AnyClass { AVPlayerLayer.self }

    private var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }

    init(url: URL) {
        super.init(frame: .zero)
        backgroundColor = .black
        player.isMuted = true
        playerLayer.player = player
        playerLayer.videoGravity = .resizeAspectFill
        play(url: url)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func play(url: URL) {
        guard currentURL != url else {
            player.play()
            return
        }

        currentURL = url
        playerLooper = nil
        player.removeAllItems()
        playerLooper = AVPlayerLooper(player: player, templateItem: AVPlayerItem(url: url))
        player.play()
    }

    func stop() {
        player.pause()
        playerLooper = nil
        player.removeAllItems()
    }
}
