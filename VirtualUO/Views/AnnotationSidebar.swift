import SwiftUI

struct AnnotationSidebar: View {
    let annotations: [Annotation]
    let onSelect: (Annotation) -> Void
    @Binding var isOpen: Bool

    private let accent = Color(red: 0.0, green: 1.0, blue: 0.53)

    var body: some View {
        HStack(spacing: 0) {
            Spacer()
            if isOpen {
                panel
                    .transition(.move(edge: .trailing))
            }
        }
    }

    private var panel: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider().background(accent.opacity(0.2))
            list
        }
        .frame(width: 270)
        .background(
            ZStack {
                Color.black.opacity(0.7)
                LinearGradient(
                    colors: [accent.opacity(0.06), Color.clear],
                    startPoint: .leading, endPoint: .trailing
                )
            }
            .background(.ultraThinMaterial)
        )
        .overlay(
            Rectangle()
                .frame(width: 1)
                .foregroundColor(accent.opacity(0.3)),
            alignment: .leading
        )
    }

    private var header: some View {
        HStack {
            Image(systemName: "list.bullet.circle.fill")
                .font(.system(size: 20))
                .foregroundColor(accent)
            Text("ADNOTARI")
                .font(.system(size: 15, weight: .black))
                .foregroundColor(.white)
                .tracking(1)
            Spacer()
            Text("\(annotations.count)")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.black)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(accent)
                .clipShape(Capsule())
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    isOpen = false
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .padding(16)
    }

    private var list: some View {
        ScrollView {
            VStack(spacing: 8) {
                ForEach(Array(annotations.enumerated()), id: \.element.id) { index, ann in
                    Button {
                        onSelect(ann)
                    } label: {
                        rowView(index: index, annotation: ann)
                    }
                }
            }
            .padding(12)
        }
    }

    private func rowView(index: Int, annotation: Annotation) -> some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(accent.opacity(0.18))
                    .frame(width: 30, height: 30)
                Text("\(index + 1)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(accent)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(annotation.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                if let text = annotation.text {
                    Text(text)
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.5))
                        .lineLimit(1)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(accent.opacity(0.7))
        }
        .padding(10)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(accent.opacity(0.2), lineWidth: 1)
        )
    }
}
