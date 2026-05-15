import SwiftUI

struct ContentView: View {
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color(red: 0.02, green: 0.03, blue: 0.06),
                    Color(red: 0.05, green: 0.10, blue: 0.18)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {
                // Logo cerc cu icon AR
                ZStack {
                    Circle()
                        .fill(Color(red: 0.0, green: 1.0, blue: 0.53).opacity(0.15))
                        .frame(width: 120, height: 120)

                    Circle()
                        .stroke(Color(red: 0.0, green: 1.0, blue: 0.53), lineWidth: 2)
                        .frame(width: 120, height: 120)

                    Text("🥽")
                        .font(.system(size: 60))
                }

                Text("VIRTUAL UO")
                    .font(.system(size: 32, weight: .black, design: .rounded))
                    .foregroundColor(Color(red: 0.18, green: 0.83, blue: 0.75))
                    .tracking(2)

                Text("AR Engine — Native iOS")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.gray)

                VStack(spacing: 8) {
                    StatusRow(label: "Build Swift", status: "OK")
                    StatusRow(label: "SwiftUI", status: "OK")
                    StatusRow(label: "RealityKit", status: "Ready")
                    StatusRow(label: "Supabase", status: "Pasul 2")
                }
                .padding(20)
                .background(Color.white.opacity(0.05))
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color(red: 0.0, green: 1.0, blue: 0.53).opacity(0.3), lineWidth: 1)
                )
                .padding(.horizontal, 30)
                .padding(.top, 20)

                Text("✓ Pasul 1 finalizat\nUrmează implementarea ecranelor AR")
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.top, 10)
            }
        }
    }
}

struct StatusRow: View {
    let label: String
    let status: String

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
            Spacer()
            Text(status)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(Color(red: 0.0, green: 1.0, blue: 0.53))
                .padding(.horizontal, 10)
                .padding(.vertical, 3)
                .background(Color(red: 0.0, green: 1.0, blue: 0.53).opacity(0.15))
                .cornerRadius(6)
        }
    }
}

#Preview {
    ContentView()
}
