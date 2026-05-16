import AVFoundation

// Text-to-Speech in romana
class TTSService {
    static let shared = TTSService()
    private let synthesizer = AVSpeechSynthesizer()
    private init() {}

    func speak(_ text: String) {
        stop()
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "ro-RO")
        utterance.rate = 0.48
        utterance.pitchMultiplier = 1.0
        synthesizer.speak(utterance)
    }

    func stop() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
    }
}
