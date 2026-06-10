import SwiftUI

// ====================================================================
//  LISTA EXPERIENȚELOR — PREMIUM
//  Thumbnails reale din DB, căutare, badge-uri, progres local, cont.
// ====================================================================
struct ExperienceListView: View {
    @State private var experiences: [Experience] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedExperience: Experience?
    @State private var search = ""
    @State private var showLogin = false
    @State private var showProfile = false

    @ObservedObject private var auth = AuthService.shared

    private var filtered: [Experience] {
        let q = search.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return experiences }
        return experiences.filter { $0.title.lowercased().contains(q) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                UOBackground()

                VStack(spacing: 0) {
                    headerView
                    contentView
                }
            }
            .navigationDestination(item: $selectedExperience) { exp in
                ExperienceDetailView(experience: exp)
            }
            .sheet(isPresented: $showLogin) { LoginView() }
            .sheet(isPresented: $showProfile) {
                ProfileSheet(experiences: experiences)
                    .presentationDetents([.medium])
            }
        }
        .task { await loadExperiences() }
    }

    // MARK: - Header
    private var headerView: some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                Image("Logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 38, height: 38)

                VStack(alignment: .leading, spacing: 1) {
                    Text("VIRTUAL UO")
                        .font(.system(size: 19, weight: .black, design: .rounded))
                        .foregroundStyle(UO.heroGradient)
                        .tracking(2)
                    Text("EXPERIENȚE XR · LIVING LAB")
                        .font(.system(size: 8.5, weight: .bold))
                        .foregroundColor(.white.opacity(0.4))
                        .tracking(2)
                }

                Spacer()

                Button {
                    Task { await loadExperiences() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(UO.teal)
                        .padding(10)
                        .background(UO.teal.opacity(0.12))
                        .clipShape(Circle())
                }

                // CONT: avatar dacă e logat, altfel buton login
                Button {
                    if auth.isLoggedIn { showProfile = true } else { showLogin = true }
                } label: {
                    if auth.isLoggedIn {
                        Text(auth.initials)
                            .font(.system(size: 13, weight: .black))
                            .foregroundColor(.black)
                            .frame(width: 38, height: 38)
                            .background(UO.heroGradient)
                            .clipShape(Circle())
                            .shadow(color: UO.blue.opacity(0.4), radius: 8)
                    } else {
                        Image(systemName: "person.fill")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(UO.blue)
                            .padding(10)
                            .background(UO.blue.opacity(0.12))
                            .clipShape(Circle())
                    }
                }
            }

            // CĂUTARE
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.4))
                TextField("", text: $search, prompt:
                    Text("Caută lecții...").foregroundColor(.white.opacity(0.3)))
                    .font(.system(size: 14))
                    .foregroundColor(.white)
                    .autocorrectionDisabled()
                if !search.isEmpty {
                    Button { search = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.white.opacity(0.35))
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(Color.white.opacity(0.06))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color.white.opacity(0.1), lineWidth: 1))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial)
    }

    // MARK: - Conținut
    @ViewBuilder
    private var contentView: some View {
        if isLoading {
            Spacer()
            ProgressView()
                .progressViewStyle(.circular)
                .tint(UO.teal)
                .scaleEffect(1.5)
            Text("Se încarcă experiențele...")
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.5))
                .padding(.top, 16)
            Spacer()
        } else if let error = errorMessage {
            Spacer()
            VStack(spacing: 16) {
                Image(systemName: "wifi.exclamationmark")
                    .font(.system(size: 46))
                    .foregroundColor(UO.red)
                Text("Eroare la încărcare")
                    .font(.headline)
                    .foregroundColor(.white)
                Text(error)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
                Button("Reîncearcă") { Task { await loadExperiences() } }
                    .buttonStyle(.borderedProminent)
                    .tint(UO.teal)
            }
            Spacer()
        } else if filtered.isEmpty {
            Spacer()
            VStack(spacing: 10) {
                Image(systemName: search.isEmpty ? "shippingbox" : "magnifyingglass")
                    .font(.system(size: 42))
                    .foregroundColor(.white.opacity(0.25))
                Text(search.isEmpty ? "Nicio experiență disponibilă" : "Niciun rezultat pentru „\(search)\"")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.5))
            }
            Spacer()
        } else {
            ScrollView {
                LazyVStack(spacing: 18) {
                    ForEach(Array(filtered.enumerated()), id: \.element.id) { _, exp in
                        PremiumExperienceCard(experience: exp) {
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

// ====================================================================
//  CARD PREMIUM — thumbnail real + badge-uri + chips + progres
// ====================================================================
struct PremiumExperienceCard: View {
    let experience: Experience
    let onTap: () -> Void

    private var progressInfo: (done: Int, total: Int) {
        let total = experience.taskCount
        guard total > 0 else { return (0, 0) }
        let prog = ProgressService.shared.getProgress(experienceId: experience.id)
        let done = prog.values.filter { $0 == .success }.count
        return (min(done, total), total)
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                visual
                info
            }
            .glassCard(cornerRadius: 22, borderColor: UO.blue.opacity(0.22))
        }
        .buttonStyle(CardPressStyle())
    }

    // ============ THUMBNAIL ============
    private var visual: some View {
        ZStack(alignment: .topLeading) {
            // Color.clear + overlay: imaginea NU mai poate împinge layout-ul
            // peste marginile cardului (scaledToFill depășea cadrul)
            Color.clear
                .frame(height: 158)
                .frame(maxWidth: .infinity)
                .overlay(
                    Group {
                        if let thumb = experience.thumbnail_url, let url = URL(string: thumb) {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .success(let img):
                                    img.resizable().scaledToFill()
                                case .failure:
                                    placeholder
                                default:
                                    ZStack { placeholderBG; ProgressView().tint(UO.teal) }
                                }
                            }
                        } else {
                            placeholder
                        }
                    }
                )
                .clipped()
                .overlay(
                    LinearGradient(colors: [.clear, .clear, UO.bgBottom.opacity(0.85)],
                                   startPoint: .top, endPoint: .bottom)
                )

            // BADGE-URI stânga-sus
            HStack(spacing: 6) {
                if experience.isNew { UOBadge(text: "NOU", color: UO.green) }
                if experience.hasModel { UOBadge(text: "AR", color: UO.teal) }
                if experience.has360 { UOBadge(text: "360°", color: UO.purple) }
            }
            .padding(10)

            // COMPLETĂRI dreapta-jos
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    HStack(spacing: 5) {
                        Image(systemName: "checkmark.seal.fill").font(.system(size: 11))
                        Text("\(experience.completions_count ?? 0)")
                            .font(.system(size: 12, weight: .black))
                    }
                    .foregroundColor(UO.green)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.black.opacity(0.55))
                    .clipShape(Capsule())
                    .padding(10)
                }
            }
        }
    }

    private var placeholderBG: some View {
        LinearGradient(colors: [UO.blue.opacity(0.18), UO.bgBottom],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    private var placeholder: some View {
        ZStack {
            placeholderBG
            Image(systemName: "cube.transparent")
                .font(.system(size: 44, weight: .light))
                .foregroundColor(UO.blue.opacity(0.7))
                .shadow(color: UO.blue.opacity(0.6), radius: 14)
        }
    }

    // ============ INFO ============
    private var info: some View {
        VStack(alignment: .leading, spacing: 11) {
            Text(experience.title)
                .font(.system(size: 16.5, weight: .bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.leading)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 7) {
                UOChip(icon: "cube.fill", text: "\(experience.modelsCount)", color: UO.teal)
                UOChip(icon: "mappin.circle.fill", text: "\(experience.annotations?.count ?? 0)", color: UO.green)
                if experience.taskCount > 0 {
                    let p = progressInfo
                    UOChip(icon: "checklist", text: "\(p.done)/\(p.total)",
                           color: p.done == p.total ? UO.green : UO.yellow)
                }
                Spacer()
                HStack(spacing: 4) {
                    Text("DESCHIDE").font(.system(size: 11, weight: .black)).tracking(1)
                    Image(systemName: "arrow.right").font(.system(size: 10, weight: .black))
                }
                .foregroundColor(UO.blue)
            }

            // PROGRES local
            if progressInfo.total > 0 {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.08))
                        Capsule()
                            .fill(LinearGradient(colors: [UO.blue, UO.green],
                                                 startPoint: .leading, endPoint: .trailing))
                            .frame(width: geo.size.width * CGFloat(progressInfo.done) / CGFloat(progressInfo.total))
                    }
                }
                .frame(height: 5)
            }
        }
        .padding(16)
    }
}

// Apăsare cu micro-animație
struct CardPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// ====================================================================
//  PROFIL — sheet cu datele contului + statistici locale + logout
// ====================================================================
struct ProfileSheet: View {
    let experiences: [Experience]
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var auth = AuthService.shared

    private var completedCount: Int {
        experiences.filter { exp in
            guard exp.taskCount > 0 else { return false }
            let prog = ProgressService.shared.getProgress(experienceId: exp.id)
            return prog.values.filter { $0 == .success }.count >= exp.taskCount
        }.count
    }

    var body: some View {
        ZStack {
            UOBackground()

            VStack(spacing: 22) {
                Capsule().fill(Color.white.opacity(0.25)).frame(width: 40, height: 5).padding(.top, 12)

                Text(auth.initials)
                    .font(.system(size: 28, weight: .black))
                    .foregroundColor(.black)
                    .frame(width: 84, height: 84)
                    .background(UO.heroGradient)
                    .clipShape(Circle())
                    .shadow(color: UO.blue.opacity(0.45), radius: 16)

                VStack(spacing: 4) {
                    Text(auth.fullName ?? "Utilizator")
                        .font(.system(size: 20, weight: .black))
                        .foregroundColor(.white)
                    Text(auth.email ?? "")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.5))
                }

                HStack(spacing: 14) {
                    statBox(value: "\(completedCount)", label: "LECȚII\nFINALIZATE", color: UO.green)
                    statBox(value: "\(experiences.count)", label: "LECȚII\nDISPONIBILE", color: UO.blue)
                }
                .padding(.horizontal, 24)

                Text("Progresul sarcinilor este salvat pe acest dispozitiv.")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.35))

                Button {
                    auth.signOut()
                    dismiss()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                        Text("DECONECTARE")
                    }
                    .font(.system(size: 14, weight: .black))
                    .foregroundColor(UO.red)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(UO.red.opacity(0.1))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(UO.red.opacity(0.5), lineWidth: 1.5))
                }
                .padding(.horizontal, 24)

                Spacer()
            }
        }
    }

    private func statBox(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.system(size: 30, weight: .black))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.white.opacity(0.45))
                .tracking(1)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .glassCard(cornerRadius: 18)
    }
}

extension Experience: Hashable {
    static func == (lhs: Experience, rhs: Experience) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}