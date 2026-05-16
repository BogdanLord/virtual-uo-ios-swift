import AVFoundation

class TTSService {
    static let shared = TTSService()
    private let synthesizer = AVSpeechSynthesizer()
    private init() {}

    func speak(_ text: String, voice: String? = nil) {
        stop()
        let utterance = AVSpeechUtterance(string: text)
        // ttsVoice din DB poate fi gen "ro-MI" - folosim ro-RO ca baza
        let langCode = (voice?.hasPrefix("ro") == true) ? "ro-RO" : "ro-RO"
        utterance.voice = AVSpeechSynthesisVoice(language: langCode)
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
