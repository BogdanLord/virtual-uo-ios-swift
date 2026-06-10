import Foundation

// MARK: - Supabase Service (REST API direct, fara SDK)
class SupabaseService {
    static let shared = SupabaseService()

    // Folosite și de AuthService
    static let baseURL = "https://supabase.virtual.uoradea.ro"
    static let anonKey = "eyJhbGciOiAiSFMyNTYiLCAidHlwIjogIkpXVCJ9.eyJyb2xlIjogImFub24iLCAiaXNzIjogInN1cGFiYXNlIiwgImlhdCI6IDE3MDAwMDAwMDAsICJleHAiOiAxOTAwMDAwMDAwfQ.eFCERyIDXdGWyebj-da04YJVTUmJ1H2UjXt18CJVKzw"

    private init() {}

    // MARK: - Fetch experiente publice
    func fetchExperiences() async throws -> [Experience] {
        let endpoint = "\(SupabaseService.baseURL)/rest/v1/public_3d_experiences?select=*&order=created_at.desc"
        guard let url = URL(string: endpoint) else { throw SupabaseError.invalidURL }

        var request = URLRequest(url: url)
        request.addValue(SupabaseService.anonKey, forHTTPHeaderField: "apikey")
        request.addValue("Bearer \(SupabaseService.anonKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResp = response as? HTTPURLResponse else { throw SupabaseError.noResponse }
        guard (200...299).contains(httpResp.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "?"
            throw SupabaseError.httpError(httpResp.statusCode, body)
        }

        // Modelul Experience are acum decodare tolerantă per câmp,
        // dar dacă o lecție întreagă e coruptă o sărim fără să picăm tot fetch-ul.
        do {
            return try JSONDecoder().decode([Experience].self, from: data)
        } catch {
            print("🔴 Decode integral eșuat (\(error)) — parsez lecțiile una câte una")
            return parsePerRow(data: data)
        }
    }

    /// Fallback: decodează fiecare rând separat și sare peste cele corupte
    private func parsePerRow(data: Data) -> [Experience] {
        guard let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return [] }
        return arr.compactMap { dict in
            guard let rowData = try? JSONSerialization.data(withJSONObject: dict) else { return nil }
            do {
                return try JSONDecoder().decode(Experience.self, from: rowData)
            } catch {
                print("🔴 DROP lecție \(dict["id"] ?? "?"): \(error)")
                return nil
            }
        }
    }

    // MARK: - Incrementare completări (RPC-ul folosit și de platforma web)
    func incrementCompletion(experienceId: String) async {
        let endpoint = "\(SupabaseService.baseURL)/rest/v1/rpc/increment_completion"
        guard let url = URL(string: endpoint) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue(SupabaseService.anonKey, forHTTPHeaderField: "apikey")
        request.addValue("Bearer \(AuthService.shared.accessToken ?? SupabaseService.anonKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["exp_id": experienceId])

        _ = try? await URLSession.shared.data(for: request)
    }
}

enum SupabaseError: LocalizedError {
    case invalidURL
    case noResponse
    case httpError(Int, String)
    case parseError

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "URL invalid"
        case .noResponse: return "Niciun raspuns primit"
        case .httpError(let code, let body): return "HTTP \(code): \(body.prefix(200))"
        case .parseError: return "Eroare la parsarea JSON-ului"
        }
    }
}