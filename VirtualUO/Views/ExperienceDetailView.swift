import SwiftUI

// ====================================================================
//  DETALII EXPERIENȚĂ — PREMIUM
//  Hero cu thumbnail real, badge-uri, două moduri: AR + Vizionare 3D
// ====================================================================
struct ExperienceDetailView: View {
    let experience: Experience
    @State private var showAR = false
    @State private var showViewer = false

    var body: some View {
        ZStack {
            UOBackground()

            ScrollView {
                VStack(spacing: 22) {
                    heroSection
                    actionButtons
                    statsCard
                    if experience.has360 { hint360 }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle("Detalii")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .fullScreenCover(isPresented: $showAR) {
            ARExperienceView(experience: experience)
        }
        .fullScreenCover(isPresented: $showViewer) {
            Viewer3DView(experience: experience)
        }
    }

    // MARK: - Hero cu thumbnail
    private var heroSection: some View {
        ZStack(alignment: .bottomLeading) {
            Group {
                if let thumb = experience.thumbnail_url, let url = URL(string: thumb) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let img): img.resizable().scaledToFill()
                        default: heroPlaceholder
                        }
                    }
                } else {
                    heroPlaceholder
                }
            }
            .frame(height: 230)
            .frame(maxWidth: .infinity)
            .clipped()
            .overlay(
                LinearGradient(colors: [.clear, UO.bgBottom.opacity(0.92)],
                               startPoint: .center, endPoint: .bottom)
            )

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    if experience.isNew { UOBadge(text: "NOU", color: UO.green) }
                    if experience.hasModel { UOBadge(text: "AR", color: UO.teal) }
                    if experience.has360 { UOBadge(text: "FUNDAL 360°", color: UO.purple) }
                }
                Text(experience.title)
                    .font(.system(size: 23, weight: .black))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.leading)
                    .shadow(color: .black.opacity(0.7), radius: 8)
            }
            .padding(18)
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(UO.blue.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.5), radius: 18, y: 10)
        .padding(.top, 14)
    }

    private var heroPlaceholder: some View {
        ZStack {
            LinearGradient(colors: [UO.blue.opacity(0.22), UO.bgBottom],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            Image(systemName: "cube.transparent")
                .font(.system(size: 64, weight: .light))
                .foregroundColor(UO.blue.opacity(0.7))
                .shadow(color: UO.blue.opacity(0.6), radius: 18)
        }
    }

    // MARK: - Butoane mod AR / Vizionare
    private var actionButtons: some View {
        VStack(spacing: 12) {
            UOPrimaryButton(icon: "arkit", title: "LANSEAZĂ ÎN AR") {
                showAR = true
            }
            .opacity(experience.hasModel ? 1 : 0.4)
            .disabled(!experience.hasModel)

            UOSecondaryButton(icon: "rotate.3d.fill", title: "VIZIONARE 3D", color: UO.teal) {
                showViewer = true
            }
            .opacity(experience.hasModel ? 1 : 0.4)
            .disabled(!experience.hasModel)

            if !experience.hasModel {
                Text("Această lecție nu are încă un model 3D publicat.")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.4))
            }
        }
    }

    // MARK: - Statistici
    private var statsCard: some View {
        VStack(spacing: 0) {
            statRow(icon: "cube.fill", color: UO.teal, label: "Modele 3D",
                    value: "\(experience.modelsCount)")
            divider
            statRow(icon: "mappin.circle.fill", color: UO.green, label: "Adnotări interactive",
                    value: "\(experience.annotations?.count ?? 0)")
            divider
            statRow(icon: "checklist", color: UO.yellow, label: "Sarcini (misiuni)",
                    value: "\(experience.taskCount)")
            divider
            statRow(icon: "checkmark.seal.fill", color: UO.green, label: "Completări globale",
                    value: "\(experience.completions_count ?? 0)")
            if let date = experience.createdDate {
                divider
                statRow(icon: "calendar", color: UO.blue, label: "Publicată",
                        value: date.formatted(.dateTime.day().month(.abbreviated).year()))
            }
        }
        .padding(.vertical, 6)
        .glassCard(cornerRadius: 20)
    }

    private var divider: some View {
        Rectangle().fill(Color.white.opacity(0.06)).frame(height: 1).padding(.horizontal, 16)
    }

    private func statRow(icon: String, color: Color, label: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundColor(color)
                .frame(width: 34, height: 34)
                .background(color.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            Text(label)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white.opacity(0.75))
            Spacer()
            Text(value)
                .font(.system(size: 15, weight: .black))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
    }

    // MARK: - Hint 360
    private var hint360: some View {
        HStack(spacing: 12) {
            Image(systemName: "globe.americas.fill")
                .font(.system(size: 22))
                .foregroundColor(UO.purple)
            VStack(alignment: .leading, spacing: 3) {
                Text("Fundal 360° disponibil")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                Text("În modul Vizionare 3D îl poți activa din butonul cu glob (implicit este dezactivat).")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.55))
            }
            Spacer()
        }
        .padding(16)
        .glassCard(cornerRadius: 18, borderColor: UO.purple.opacity(0.35))
    }
}