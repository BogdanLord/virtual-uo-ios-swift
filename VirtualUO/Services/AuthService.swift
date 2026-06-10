import Foundation
import Combine

// ====================================================================
//  AUTH SERVICE — login cu contul de pe platforma web Virtual UO
//  Folosește REST-ul Supabase Auth (fără SDK), sesiune în UserDefaults.
// ====================================================================
@MainActor
final class AuthService: ObservableObject {
    static let shared = AuthService()

    @Published var userId: String?
    @Published var email: String?
    @Published var fullName: String?

    private(set) var accessToken: String?

    var isLoggedIn: Bool { userId != nil }

    /// Inițialele pentru avatar (ex: "Bogdan Popescu" -> "BP")
    var initials: String {
        let src = (fullName?.isEmpty == false ? fullName! : (email ?? "?"))
        let parts = src.split(separator: " ")
        if parts.count >= 2 { return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased() }
        return String(src.prefix(2)).uppercased()
    }

    private let dToken = "vuo_token", dUid = "vuo_uid", dEmail = "vuo_email", dName = "vuo_name"

    private init() {
        // Restaurăm sesiunea salvată
        let ud = UserDefaults.standard
        accessToken = ud.string(forKey: dToken)
        userId      = ud.string(forKey: dUid)
        email       = ud.string(forKey: dEmail)
        fullName    = ud.string(forKey: dName)
    }

    // MARK: - Login (contul se creează pe platforma web)
    func signIn(email: String, password: String) async throws {
        let endpoint = "\(SupabaseService.baseURL)/auth/v1/token?grant_type=password"
        guard let url = URL(string: endpoint) else { throw AuthError.generic("URL invalid") }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.addValue(SupabaseService.anonKey, forHTTPHeaderField: "apikey")
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: ["email": email, "password": password])

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw AuthError.generic("Niciun răspuns") }

        guard (200...299).contains(http.statusCode) else {
            // Supabase trimite {"error_description": "..."} sau {"msg": "..."}
            if let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                let msg = (dict["error_description"] as? String) ?? (dict["msg"] as? String) ?? "Email sau parolă greșite"
                throw AuthError.generic(msg)
            }
            throw AuthError.generic("Autentificare eșuată (HTTP \(http.statusCode))")
        }

        guard let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let token = dict["access_token"] as? String,
              let user = dict["user"] as? [String: Any],
              let uid = user["id"] as? String else {
            throw AuthError.generic("Răspuns invalid de la server")
        }

        accessToken = token
        userId = uid
        self.email = (user["email"] as? String) ?? email

        let ud = UserDefaults.standard
        ud.set(token, forKey: dToken)
        ud.set(uid, forKey: dUid)
        ud.set(self.email, forKey: dEmail)

        await fetchProfile()
    }

    // MARK: - Profil din tabela `profiles` (first_name, last_name)
    func fetchProfile() async {
        guard let uid = userId, let token = accessToken else { return }
        let endpoint = "\(SupabaseService.baseURL)/rest/v1/profiles?id=eq.\(uid)&select=first_name,last_name"
        guard let url = URL(string: endpoint) else { return }

        var req = URLRequest(url: url)
        req.addValue(SupabaseService.anonKey, forHTTPHeaderField: "apikey")
        req.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        guard let (data, _) = try? await URLSession.shared.data(for: req),
              let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
              let p = arr.first else { return }

        let first = (p["first_name"] as? String) ?? ""
        let last  = (p["last_name"] as? String) ?? ""
        let name = "\(first) \(last)".trimmingCharacters(in: .whitespaces)
        if !name.isEmpty {
            fullName = name
            UserDefaults.standard.set(name, forKey: dName)
        }
    }

    // MARK: - Logout
    func signOut() {
        accessToken = nil
        userId = nil
        email = nil
        fullName = nil
        let ud = UserDefaults.standard
        [dToken, dUid, dEmail, dName].forEach { ud.removeObject(forKey: $0) }
    }
}

enum AuthError: LocalizedError {
    case generic(String)
    var errorDescription: String? {
        switch self { case .generic(let m): return m }
    }
}