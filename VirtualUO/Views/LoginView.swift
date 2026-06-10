import SwiftUI

// ====================================================================
//  LOGIN — autentificare cu contul de pe platforma web Virtual UO
//  (conturile se creează pe site; aplicația doar face sign-in)
// ====================================================================
struct LoginView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var auth = AuthService.shared

    @State private var email = ""
    @State private var password = ""
    @State private var isWorking = false
    @State private var errorText: String?

    var body: some View {
        ZStack {
            UOBackground()

            ScrollView {
                VStack(spacing: 24) {
                    header
                    formCard
                }
                .padding(20)
                .padding(.top, 30)
            }
        }
    }

    private var header: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle().fill(UO.blue.opacity(0.15)).frame(width: 92, height: 92)
                Circle().stroke(UO.heroGradient, lineWidth: 2).frame(width: 92, height: 92)
                Image(systemName: "person.fill")
                    .font(.system(size: 38))
                    .foregroundStyle(UO.heroGradient)
            }
            Text("CONTUL TĂU")
                .font(.system(size: 24, weight: .black, design: .rounded))
                .foregroundColor(.white)
                .tracking(2)
            Text("Conectează-te cu contul de pe platforma Virtual UO")
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.55))
                .multilineTextAlignment(.center)
        }
    }

    private var formCard: some View {
        VStack(spacing: 16) {
            field(icon: "envelope.fill", placeholder: "Email", text: $email, isSecure: false)
            field(icon: "lock.fill", placeholder: "Parolă", text: $password, isSecure: true)

            if let err = errorText {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text(err)
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(UO.red)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button(action: doLogin) {
                Group {
                    if isWorking {
                        ProgressView().tint(.black)
                    } else {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.right.circle.fill")
                            Text("CONECTARE")
                        }
                        .font(.system(size: 15, weight: .black))
                        .tracking(1)
                    }
                }
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(UO.heroGradient)
                .clipShape(Capsule())
            }
            .disabled(isWorking || email.isEmpty || password.isEmpty)
            .opacity((email.isEmpty || password.isEmpty) ? 0.5 : 1)

            Text("Nu ai cont? Creează-l pe platforma web virtual.uoradea.ro, apoi conectează-te aici.")
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.4))
                .multilineTextAlignment(.center)
                .padding(.top, 4)

            Button("Continuă fără cont") { dismiss() }
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(UO.teal)
                .padding(.top, 2)
        }
        .padding(22)
        .glassCard(cornerRadius: 24, borderColor: UO.blue.opacity(0.3))
    }

    private func field(icon: String, placeholder: String, text: Binding<String>, isSecure: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundColor(UO.blue)
                .frame(width: 22)
            Group {
                if isSecure {
                    SecureField("", text: text, prompt: Text(placeholder).foregroundColor(.white.opacity(0.3)))
                } else {
                    TextField("", text: text, prompt: Text(placeholder).foregroundColor(.white.opacity(0.3)))
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
            }
            .font(.system(size: 15))
            .foregroundColor(.white)
        }
        .padding(14)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }

    private func doLogin() {
        errorText = nil
        isWorking = true
        Task {
            do {
                try await auth.signIn(
                    email: email.trimmingCharacters(in: .whitespaces),
                    password: password
                )
                isWorking = false
                dismiss()
            } catch {
                isWorking = false
                errorText = error.localizedDescription
            }
        }
    }
}