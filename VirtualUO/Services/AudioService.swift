import Foundation
import AVFoundation
import Combine

// ====================================================================
//  AUDIO SERVICE — redă fișierele audio atașate adnotărilor (URL-uri
//  din bucket-ul Supabase) + intro audio. Un singur player global.
// ====================================================================
@MainActor
final class AudioService: NSObject, ObservableObject {
    static let shared = AudioService()

    @Published var isPlaying = false
    @Published private(set) var currentURL: String?

    private var player: AVPlayer?

    private override init() {
        super.init()
        // Sunetul merge și cu switch-ul de silent al telefonului pe mute
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    /// Redă un URL. Dacă e același URL: toggle play/pause.
    func play(_ urlString: String) {
        if currentURL == urlString, let p = player {
            if isPlaying { p.pause(); isPlaying = false }
            else { p.play(); isPlaying = true }
            return
        }

        stop()
        guard let url = URL(string: urlString) else { return }

        let item = AVPlayerItem(url: url)
        NotificationCenter.default.addObserver(
            self, selector: #selector(itemFinished),
            name: .AVPlayerItemDidPlayToEndTime, object: item
        )

        let p = AVPlayer(playerItem: item)
        player = p
        currentURL = urlString
        p.play()
        isPlaying = true
    }

    func stop() {
        player?.pause()
        if let item = player?.currentItem {
            NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: item)
        }
        player = nil
        currentURL = nil
        isPlaying = false
    }

    /// Oprește TOT sunetul din aplicație (audio + TTS)
    func silenceAll() {
        stop()
        TTSService.shared.stop()
    }

    @objc private func itemFinished() {
        isPlaying = false
    }
}