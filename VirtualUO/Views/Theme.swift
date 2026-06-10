import SwiftUI
import UIKit

// ====================================================================
//  THEME — design system Virtual UO (next-gen)
//  Paleta identică cu platforma web: teal/blue/green pe fundal deep.
// ====================================================================
enum UO {
    static let blue   = Color(red: 0.00, green: 0.667, blue: 1.00)   // #00aaff
    static let teal   = Color(red: 0.176, green: 0.831, blue: 0.749) // #2dd4bf
    static let green  = Color(red: 0.00, green: 1.00, blue: 0.533)   // #00ff88
    static let yellow = Color(red: 1.00, green: 0.80, blue: 0.00)    // #ffcc00
    static let red    = Color(red: 1.00, green: 0.333, blue: 0.333)  // #ff5555
    static let purple = Color(red: 0.659, green: 0.333, blue: 0.969) // #a855f7

    static let bgTop    = Color(red: 0.043, green: 0.075, blue: 0.137)
    static let bgBottom = Color(red: 0.020, green: 0.031, blue: 0.063)

    static let heroGradient = LinearGradient(
        colors: [blue, teal], startPoint: .leading, endPoint: .trailing
    )
}

// MARK: - Fundal premium cu orbe luminoase (folosit pe toate ecranele)
struct UOBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [UO.bgTop, UO.bgBottom],
                           startPoint: .topLeading, endPoint: .bottomTrailing)

            Circle()
                .fill(UO.blue.opacity(0.14))
                .frame(width: 320, height: 320)
                .blur(radius: 80)
                .offset(x: -130, y: -260)

            Circle()
                .fill(UO.teal.opacity(0.10))
                .frame(width: 280, height: 280)
                .blur(radius: 80)
                .offset(x: 150, y: 240)
        }
        .ignoresSafeArea()
    }
}

// MARK: - Card glassmorphism
struct GlassCard: ViewModifier {
    var cornerRadius: CGFloat = 20
    var borderColor: Color = .white.opacity(0.12)

    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    Color.black.opacity(0.45)
                    LinearGradient(colors: [Color.white.opacity(0.06), .clear],
                                   startPoint: .top, endPoint: .bottom)
                }
                .background(.ultraThinMaterial)
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(borderColor, lineWidth: 1)
            )
    }
}

extension View {
    func glassCard(cornerRadius: CGFloat = 20, borderColor: Color = .white.opacity(0.12)) -> some View {
        modifier(GlassCard(cornerRadius: cornerRadius, borderColor: borderColor))
    }
}

// MARK: - Chip mic cu icon + text (statistici)
struct UOChip: View {
    let icon: String
    let text: String
    var color: Color = .white.opacity(0.7)

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon).font(.system(size: 11, weight: .bold))
            Text(text).font(.system(size: 11, weight: .bold))
        }
        .foregroundColor(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.06))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.1), lineWidth: 1))
    }
}

// MARK: - Badge colorat (NOU, AR, 360°)
struct UOBadge: View {
    let text: String
    var color: Color = UO.green

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .black))
            .tracking(0.5)
            .foregroundColor(.black)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(color)
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            .shadow(color: color.opacity(0.5), radius: 6)
    }
}

// MARK: - Buton principal (capsulă gradient)
struct UOPrimaryButton: View {
    let icon: String
    let title: String
    var gradient: LinearGradient = UO.heroGradient
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon).font(.system(size: 18, weight: .bold))
                Text(title).font(.system(size: 15, weight: .black)).tracking(1)
            }
            .foregroundColor(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(gradient)
            .clipShape(Capsule())
            .shadow(color: UO.blue.opacity(0.4), radius: 14, y: 6)
        }
    }
}

// MARK: - Buton secundar (contur)
struct UOSecondaryButton: View {
    let icon: String
    let title: String
    var color: Color = UO.teal
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon).font(.system(size: 18, weight: .bold))
                Text(title).font(.system(size: 15, weight: .black)).tracking(1)
            }
            .foregroundColor(color)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(color.opacity(0.1))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(color.opacity(0.6), lineWidth: 1.5))
        }
    }
}

// MARK: - Parser culoare hex (#1e293b) -> UIColor (pt. bg_color din DB)
extension UIColor {
    convenience init(hex: String, fallback: UIColor = UIColor(red: 0.08, green: 0.12, blue: 0.2, alpha: 1)) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let v = UInt64(s, radix: 16) else {
            self.init(cgColor: fallback.cgColor)
            return
        }
        self.init(
            red: CGFloat((v >> 16) & 0xFF) / 255.0,
            green: CGFloat((v >> 8) & 0xFF) / 255.0,
            blue: CGFloat(v & 0xFF) / 255.0,
            alpha: 1.0
        )
    }
}