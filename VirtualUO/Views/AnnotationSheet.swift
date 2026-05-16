import SwiftUI

struct AnnotationSheet: View {
    let annotation: Annotation
    let onClose: () -> Void
    @State private var appeared = false

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
            actionButtons
        }
        .padding(20)
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
            Text(annotation.title)
                .font(.system(size: 19, weight: .bold))
                .foregroundColor(.white)
            Spacer()
            Button(action: dismiss) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.white.opacity(0.4))
            }
        }
    }

    private var contentScroll: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if let text = annotation.text, !text.isEmpty {
                    Text(text)
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.85))
                        .lineSpacing(4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.vertical, 8)
        }
        .frame(maxHeight: 160)
    }

    private var actionButtons: some View {
        VStack(spacing: 10) {
            if let text = annotation.text, !text.isEmpty {
                Button {
                    TTSService.shared.speak(text, voice: annotation.ttsVoice)
                } label: {
                    actionLabel(icon: "speaker.wave.2.fill", title: "Asculta Audio")
                }
            }
            if annotation.hasLink, let link = annotation.media?.data {
                Button {
                    if let url = URL(string: link) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    actionLabel(icon: "link", title: "Deschide Link")
                }
            }
        }
        .padding(.top, 8)
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
