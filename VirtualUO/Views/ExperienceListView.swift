import SwiftUI

struct ExperienceListView: View {
    @State private var experiences: [Experience] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedExperience: Experience?

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.02, green: 0.03, blue: 0.06),
                        Color(red: 0.05, green: 0.10, blue: 0.18)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    headerView
                    contentView
                }
            }
            .navigationDestination(item: $selectedExperience) { exp in
                ExperienceDetailView(experience: exp)
            }
        }
        .task { await loadExperiences() }
    }

    private var headerView: some View {
        HStack(spacing: 12) {
            Image("Logo")
                .resizable()
                .scaledToFit()
                .frame(width: 40, height: 40)

            Text("VIRTUAL UO")
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundColor(Color(red: 0.18, green: 0.83, blue: 0.75))
                .tracking(2)

            Spacer()

            Button {
                Task { await loadExperiences() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Color(red: 0.18, green: 0.83, blue: 0.75))
                    .padding(10)
                    .background(Color(red: 0.18, green: 0.83, blue: 0.75).opacity(0.15))
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(.ultraThinMaterial)
    }

    @ViewBuilder
    private var contentView: some View {
        if isLoading {
            Spacer()
            ProgressView()
                .progressViewStyle(.circular)
                .tint(Color(red: 0.18, green: 0.83, blue: 0.75))
                .scaleEffect(1.5)
            Text("Se incarca experientele...")
                .foregroundColor(.gray)
                .padding(.top, 16)
            Spacer()
        } else if let error = errorMessage {
            Spacer()
            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 50))
                    .foregroundColor(.red)
                Text("Eroare incarcare")
                    .font(.headline)
                    .foregroundColor(.white)
                Text(error)
                    .font(.caption)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
                Button("Reincearca") {
                    Task { await loadExperiences() }
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(red: 0.18, green: 0.83, blue: 0.75))
            }
            Spacer()
        } else if experiences.isEmpty {
            Spacer()
            Text("Nicio experienta disponibila")
                .foregroundColor(.gray)
            Spacer()
        } else {
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(experiences) { exp in
                        ExperienceCard(experience: exp) {
                            selectedExperience = exp
                        }
                    }
                }
                .padding(20)
            }
        }
    }

    private func loadExperiences() async {
        isLoading = true
        errorMessage = nil
        do {
            let result = try await SupabaseService.shared.fetchExperiences()
            await MainActor.run {
                experiences = result
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }
}

struct ExperienceCard: View {
    let experience: Experience
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(experience.title)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                    Spacer()
                    if experience.model_url_ios != nil {
                        Text("AR")
                            .font(.system(size: 11, weight: .black))
                            .foregroundColor(.black)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color(red: 0.0, green: 1.0, blue: 0.53))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
                HStack {
                    Text("DESCHIDE")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Color(red: 0.0, green: 1.0, blue: 0.53))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color(red: 0.0, green: 1.0, blue: 0.53))
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.06))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color(red: 0.0, green: 1.0, blue: 0.53), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }
}

extension Experience: Hashable {
    static func == (lhs: Experience, rhs: Experience) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
