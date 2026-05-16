import SwiftUI

struct ExperienceDetailView: View {
    let experience: Experience
    @State private var showAR = false

    var body: some View {
        ZStack {
            Color(red: 0.02, green: 0.03, blue: 0.06).ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    // Hero
                    ZStack {
                        Circle()
                            .fill(Color(red: 0.0, green: 1.0, blue: 0.53).opacity(0.12))
                            .frame(width: 110, height: 110)
                        Circle()
                            .stroke(Color(red: 0.0, green: 1.0, blue: 0.53), lineWidth: 2)
                            .frame(width: 110, height: 110)
                        Text("🥽").font(.system(size: 52))
                    }
                    .padding(.top, 20)

                    Text(experience.title)
                        .font(.title2.bold())
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30)

                    // Buton AR mare
                    Button {
                        showAR = true
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "arkit")
                                .font(.system(size: 20, weight: .bold))
                            Text("LANSEAZA IN AR")
                                .font(.system(size: 16, weight: .black))
                                .tracking(1)
                        }
                        .foregroundColor(.black)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 16)
                        .background(Color(red: 0.18, green: 0.83, blue: 0.75))
                        .clipShape(Capsule())
                        .shadow(color: Color(red: 0.18, green: 0.83, blue: 0.75).opacity(0.5), radius: 12)
                    }

                    // Info
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
                }
                .padding(.bottom, 40)
            }
        }
        .navigationTitle("Detalii")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .fullScreenCover(isPresented: $showAR) {
            ARExperienceView(experience: experience)
        }
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
