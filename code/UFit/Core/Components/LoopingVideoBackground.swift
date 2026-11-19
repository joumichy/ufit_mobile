import SwiftUI
import AVFoundation
import UIKit

/// A silent decorative film. Its poster remains visible until the first frame and on playback failure.
struct UFitLoopingVideoBackground: UIViewRepresentable {
    let url: URL?
    let posterName: String
    let isActive: Bool

    func makeUIView(context: Context) -> VideoSurface {
        VideoSurface(url: url, posterName: posterName)
    }
    func updateUIView(_ view: VideoSurface, context: Context) { view.setPlaybackActive(isActive) }
    static func dismantleUIView(_ view: VideoSurface, coordinator: ()) { view.stop() }

    final class VideoSurface: UIView {
        private let poster = UIImageView()
        private let video = AVPlayerLayer()
        private let player = AVQueuePlayer()
        private var looper: AVPlayerLooper?
        private var displayObservation: NSKeyValueObservation?
        private var playerObservation: NSKeyValueObservation?
        private var looperObservation: NSKeyValueObservation?
        private var playbackActive = false
        private var playbackFailed = false

        init(url: URL?, posterName: String) {
            super.init(frame: .zero)
            clipsToBounds = true
            isUserInteractionEnabled = false
            isAccessibilityElement = false
            accessibilityElementsHidden = true
            backgroundColor = UIColor(Color.ufitInk)
            poster.image = UIImage(named: posterName)
            poster.contentMode = .scaleAspectFill
            poster.clipsToBounds = true
            video.videoGravity = .resizeAspectFill
            layer.addSublayer(video)
            addSubview(poster)
            guard let url else { return }
            player.isMuted = true
            player.volume = .zero
            player.preventsDisplaySleepDuringVideoPlayback = false
            video.player = player
            looper = AVPlayerLooper(player: player, templateItem: AVPlayerItem(url: url))
            displayObservation = video.observe(\.isReadyForDisplay, options: [.initial, .new]) { [weak self] layer, _ in
                let ready = layer.isReadyForDisplay
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.poster.isHidden = ready && !self.playbackFailed
                }
            }
            playerObservation = player.observe(\.status, options: [.initial, .new]) { [weak self] player, _ in
                guard player.status == .failed else { return }
                Task { @MainActor [weak self] in self?.showPosterAfterFailure() }
            }
            looperObservation = looper?.observe(\.status, options: [.initial, .new]) { [weak self] looper, _ in
                guard looper.status == .failed else { return }
                Task { @MainActor [weak self] in self?.showPosterAfterFailure() }
            }
        }
        required init?(coder: NSCoder) { return nil }
        override func layoutSubviews() {
            super.layoutSubviews()
            poster.frame = bounds
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            video.frame = bounds
            CATransaction.commit()
        }
        func setPlaybackActive(_ active: Bool) {
            guard active != playbackActive else { return }
            playbackActive = active
            if active && !playbackFailed { player.play() } else { player.pause() }
        }
        private func showPosterAfterFailure() {
            playbackFailed = true
            player.pause()
            poster.isHidden = false
        }
        func stop() {
            player.pause()
            displayObservation?.invalidate(); playerObservation?.invalidate(); looperObservation?.invalidate()
            displayObservation = nil; playerObservation = nil; looperObservation = nil
            looper?.disableLooping(); looper = nil
            player.removeAllItems(); video.player = nil
        }
    }
}
