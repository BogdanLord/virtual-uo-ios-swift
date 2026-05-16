import Foundation

// Descarca fisierul USDZ pe disk si returneaza URL-ul local
class ARModelDownloader {
    static let shared = ARModelDownloader()
    private init() {}

    func downloadModel(from urlString: String) async throws -> URL {
        guard let url = URL(string: urlString) else {
            throw DownloadError.invalidURL
        }

        // Nume fisier local in cache
        let fileName = url.lastPathComponent.isEmpty ? "model.usdz" : url.lastPathComponent
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let localURL = cacheDir.appendingPathComponent(fileName)

        // Daca exista deja in cache, il folosim direct
        if FileManager.default.fileExists(atPath: localURL.path) {
            let attrs = try? FileManager.default.attributesOfItem(atPath: localURL.path)
            let size = (attrs?[.size] as? Int) ?? 0
            if size > 1000 {
                print("Model din cache: \(localURL.lastPathComponent)")
                return localURL
            }
        }

        // Descarcam
        print("Descarc model: \(urlString)")
        let (tempURL, response) = try await URLSession.shared.download(from: url)

        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw DownloadError.httpError(http.statusCode)
        }

        // Mutam din temp in cache
        try? FileManager.default.removeItem(at: localURL)
        try FileManager.default.moveItem(at: tempURL, to: localURL)

        print("Model descarcat: \(localURL.lastPathComponent)")
        return localURL
    }
}

enum DownloadError: LocalizedError {
    case invalidURL
    case httpError(Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "URL model invalid"
        case .httpError(let code): return "Eroare descarcare HTTP \(code)"
        }
    }
}
