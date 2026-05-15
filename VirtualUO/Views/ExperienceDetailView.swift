@'
import SwiftUI

struct ExperienceDetailView: View {
    let experience: Experience

    var body: some View {
        ZStack {
            Color(red: 0.02, green: 0.03, blue: 0.06).ignoresSafeArea()

            VStack(spacing: 24) {
                Text("🥽")
                    .font(.system(size: 80))

                Text(experience.title)
                    .font(.title2.bold())
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)

                VStack(alignment: .leading, spacing: 8) {
                    InfoRow(label: "ID", value: "\(experience.id)")
                    InfoRow(label: "GLB", value: experience.model_url != nil ? "Da" : "Nu")
                    InfoRow(label: "USDZ", value: experience.model_url_ios != nil ? "Da" : "Nu")
                    InfoRow(label: "Adnotari", value: "\(experience.annotations?.count ?? 0)")
                    InfoRow(label: "Tasks", value: "\((experience.localizations?.count ?? 0) + (experience.identifications?.count ?? 0) + (experience.quizzes?.count ?? 0))")
                }
                .padding(20)
                .background(Color.white.opacity(0.05))
                .cornerRadius(14)
                .padding(.horizontal, 30)

                Text("Pasul 3: AR cu RealityKit (urmeaza)")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(.top, 20)
            }
        }
        .navigationTitle("Detalii")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 14))
                .foregroundColor(.gray)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color(red: 0.18, green: 0.83, blue: 0.75))
        }
    }
}
'@ | Out-File -Encoding utf8 VirtualUO\Views\ExperienceDetailView.swift