import SwiftUI

// ====================================================================
//  ANNOTATION SHEET — PREMIUM, cu MEDIA MULTIPLĂ
//  • audio atașat -> player propriu (butonul TTS dispare)
//  • imagini afișate inline
//  • linkuri / PDF / video -> carduri cu deschidere în browser
//  Semnătura AnnotationSheet(annotation:onClose:) e neschimbată,
//  deci ARExperienceView funcționează fără modificări.
// ====================================================================
struct AnnotationSheet: View {
    let annotation: Annotation
    let onClose: () -> Void

    @State private var appeared = false
    @ObservedObject private var audio = AudioService.shared

    private let accent = Color(red: 0.0, green: 1.0, blue: 0.53)

    var body: some View {
        VStack {
            Spacer()
            card
                .offset(y: appeared ? 0 : 400)
                .opacity(appeared ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                appeared = true
            }
        }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 0) {
            handleBar
            headerRow
            Divider().background(accent.opacity(0.2)).padding(.vertical, 4)
            contentScroll
        }
        .padding(20)
        .frame(maxWidth: 520)
        .background(sheetBackground)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(accent.opacity(0.4), lineWidth: 1)
        )
        .padding(.horizontal, 14)
        .padding(.bottom, 20)
        .shadow(color: accent.opacity(0.3), radius: 20)
    }

    private var handleBar: some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(Color.white.opacity(0.25))
            .frame(width: 40, height: 5)
            .frame(maxWidth: .infinity)
            .padding(.bottom, 12)
    }

    private var headerRow: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(accent.opacity(0.18))
                    .frame(width: 40, height: 40)
                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: 22))
                    .foregroundColor(accent)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("ADNOTARE")
                    .font(.system(size: 9, weight: .black))
                    .foregroundColor(.white.opacity(0.35))
                    .tracking(2)
                Text(annotation.title)
                    .font(.system(size: 19, weight: .bold))
                    .foregroundColor(.white)
            }
            Spacer()
            Button(action: dismiss) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.white.opacity(0.4))
            }
        }
    }

    // MARK: - Conținut: text + TTS/audio + media
    private var contentScroll: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if let text = annotation.text, !text.isEmpty {
                    Text(text)
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.85))
                        .lineSpacing(4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                // AUDIO atașat are prioritate -> ascundem TTS-ul
                if let audioItem = annotation.audioItem {
                    audioPlayerCard(audioItem)
                } else if let text = annotation.text, !text.isEmpty {
                    Button {
                        TTSService.shared.speak(text, voice: annotation.ttsVoice)
                    } label: {
                        actionLabel(icon: "speaker.wave.2.fill", title: "Ascultă (AI)")
                    }
                }

                // MEDIA (toate elementele atașate)
                ForEach(annotation.media.filter { !$0.isAudio }) { item in
                    mediaRow(item)
                }
            }
            .padding(.vertical, 8)
        }
        .frame(maxHeight: 320)
    }

    // MARK: - Player audio premium
    private func audioPlayerCard(_ item: MediaItem) -> some View {
        let isThis = audio.currentURL == item.data
        let playing = isThis && audio.isPlaying

        return Button {
            audio.play(item.data)
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(accent).frame(width: 44, height: 44)
                    Image(systemName: playing ? "pause.fill" : "play.fill")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.black)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name ?? "Audio")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Text(playing ? "Se redă... atinge pentru pauză" : "Atinge pentru redare")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.5))
                }
                Spacer()
                Image(systemName: "waveform")
                    .font(.system(size: 18))
                    .foregroundColor(accent.opacity(playing ? 1 : 0.4))
            }
            .padding(12)
            .background(accent.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(accent.opacity(0.4), lineWidth: 1)
            )
        }
    }

    // MARK: - Rânduri media (imagine / link / pdf / video)
    @ViewBuilder
    private func mediaRow(_ item: MediaItem) -> some View {
        if item.isImage, let url = URL(string: item.data) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let img):
                    img.resizable()
                        .scaledToFit()
                        .frame(maxHeight: 190)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.white.opacity(0.15), lineWidth: 1)
                        )
                case .failure:
                    EmptyView()
                default:
                    ProgressView().tint(accent).frame(maxWidth: .infinity).padding()
                }
            }
        } else if let url = URL(string: item.data) {
            Button {
                UIApplication.shared.open(url)
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 11)
                            .fill(linkColor(item).opacity(0.15))
                            .frame(width: 44, height: 44)
                        Image(systemName: linkIcon(item))
                            .font(.system(size: 18))
                            .foregroundColor(linkColor(item))
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.name ?? linkTitle(item))
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        Text(url.host ?? item.data)
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.45))
                            .lineLimit(1)
                    }
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white.opacity(0.4))
                }
                .padding(12)
                .background(Color.white.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
            }
        }
    }

    private func linkIcon(_ item: MediaItem) -> String {
        switch item.type {
        case "video": return "play.rectangle.fill"
        case "pdf": return "doc.text.fill"
        default: return "link"
        }
    }

    private func linkColor(_ item: MediaItem) -> Color {
        switch item.type {
        case "video": return Color(red: 1, green: 0.27, blue: 0.27)
        case "pdf": return Color(red: 1, green: 0.45, blue: 0.45)
        default: return Color(red: 0, green: 0.67, blue: 1)
        }
    }

    private func linkTitle(_ item: MediaItem) -> String {
        switch item.type {
        case "video": return "Videoclip"
        case "pdf": return "Document PDF"
        default: return "Link extern"
        }
    }

    private func actionLabel(icon: String, title: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
            Text(title)
        }
        .font(.system(size: 15, weight: .bold))
        .foregroundColor(.black)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 13)
        .background(accent)
        .clipShape(Capsule())
    }

    private var sheetBackground: some View {
        ZStack {
            Color.black.opacity(0.65)
            LinearGradient(
                colors: [accent.opacity(0.08), Color.clear],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .background(.ultraThinMaterial)
    }

    private func dismiss() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            appeared = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onClose()
        }
    }
}