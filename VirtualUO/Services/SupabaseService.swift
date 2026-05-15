import Foundation

// MARK: - Supabase Service (REST API direct, fara SDK)
class SupabaseService {
    static let shared = SupabaseService()

    // ⚠️ INLOCUIESTE cu valorile tale din src/utils/supabaseClient.ts daca e cazul:
    private let supabaseURL  = "https://sqagdoaovomslcgrtwun.supabase.co"
    private let supabaseKey  = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNxYWdkb2Fvdm9tc2xjZ3J0d3VuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njg3MzYwNzUsImV4cCI6MjA4NDMxMjA3NX0.ghSvfDbirwpoXBhZ5deRrt4fieazbztqF0hc0vzGPhQ"

    private init() {}

    // MARK: - Fetch experiente publice
    func fetchExperiences() async throws -> [Experience] {
        let endpoint = "\(supabaseURL)/rest/v1/public_3d_experiences?select=*&order=created_at.desc"
        guard let url = URL(string: endpoint) else {
            throw SupabaseError.invalidURL
        }

        var request = URLRequest(url: url)
        request.addValue(supabaseKey, forHTTPHeaderField: "apikey")
        request.addValue("Bearer \(supabaseKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResp = response as? HTTPURLResponse else {
            throw SupabaseError.noResponse
        }

        guard (200...299).contains(httpResp.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "?"
            throw SupabaseError.httpError(httpResp.statusCode, body)
        }

        let decoder = JSONDecoder()
        do {
            return try decoder.decode([Experience].self, from: data)
        } catch {
            // Daca decoding-ul integral pica, incercam sa parsam manual
            print("🔴 Decode error principal, se incearca parsarea manuala: \(error)")
            return try parseExperiencesManually(data: data)
        }
    }

    // Parser manual care suporta annotations ca string sau array si afiseaza erorile in consola
    private func parseExperiencesManually(data: Data) throws -> [Experience] {
        guard let arr = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            throw SupabaseError.parseError
        }

        return arr.compactMap { dict in
            // Extragem ID-ul cu fallback pentru String
            var id: Int? = dict["id"] as? Int
            if id == nil, let idString = dict["id"] as? String {
                id = Int(idString) // Daca Supabase trimite bigint ca String
            }
            
            guard let finalId = id else {
                print("🔴 DROP [ID]: id-ul lipseste sau nu poate fi convertit in Int! Valoarea primita: \(String(describing: dict["id"]))")
                return nil
            }

            guard let title = dict["title"] as? String else {
                print("🔴 DROP [TITLE]: title lipseste sau nu este String! Valoarea primita: \(String(describing: dict["title"]))")
                return nil
            }

            return Experience(
                id: finalId,
                title: title,
                model_url: dict["model_url"] as? String,
                model_url_ios: dict["model_url_ios"] as? String,
                bg_color: dict["bg_color"] as? String,
                created_at: dict["created_at"] as? String,
                annotations: parseArray(dict["annotations"], type: Annotation.self),
                localizations: parseArray(dict["localizations"], type: LocalizationTask.self),
                identifications: parseArray(dict["identifications"], type: IdentificationTask.self),
                quizzes: parseArray(dict["quizzes"], type: QuizTask.self)
            )
        }
    }

    private func parseArray<T: Decodable>(_ value: Any?, type: T.Type) -> [T]? {
        // Cazul 1: e deja array de dictionare
        if let arr = value as? [[String: Any]] {
            guard let data = try? JSONSerialization.data(withJSONObject: arr) else { return nil }
            return try? JSONDecoder().decode([T].self, from: data)
        }
        // Cazul 2: e string JSON
        if let str = value as? String, let data = str.data(using: .utf8) {
            return try? JSONDecoder().decode([T].self, from: data)
        }
        return nil
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