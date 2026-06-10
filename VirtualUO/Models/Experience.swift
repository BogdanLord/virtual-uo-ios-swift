import Foundation

// ====================================================================
//  MODELUL DE DATE — FORMATUL NOU (multi-model, media multiplă, 360°)
//  Decodare TOLERANTĂ: o lecție cu un câmp ciudat nu mai pică tot fetch-ul.
//  Compatibil cu lecțiile vechi (model_url unic, media ca obiect unic).
// ====================================================================

// MARK: - Media atașată unei adnotări
struct MediaItem: Codable, Identifiable {
    let id: String
    let type: String      // "audio" | "video" | "pdf" | "image" | "url" | "link" (vechi)
    let data: String
    let name: String?

    init(id: String = UUID().uuidString, type: String, data: String, name: String? = nil) {
        self.id = id
        self.type = type
        self.data = data
        self.name = name
    }

    enum CodingKeys: String, CodingKey { case id, type, data, name }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id   = (try? c.decode(String.self, forKey: .id)) ?? UUID().uuidString
        type = (try? c.decode(String.self, forKey: .type)) ?? "url"
        data = (try? c.decode(String.self, forKey: .data)) ?? ""
        name = try? c.decodeIfPresent(String.self, forKey: .name)
    }

    var isAudio: Bool { type == "audio" }
    var isImage: Bool { type == "image" }
    var isLink:  Bool { type == "url" || type == "link" || type == "video" || type == "pdf" }
}

// Formatul VECHI: media era un singur obiect {type, data}
private struct LegacyMedia: Codable {
    let type: String?
    let data: String?
}

// MARK: - Model 3D (formatul nou are o LISTĂ de modele per lecție)
struct Model3D: Codable, Identifiable {
    let id: String
    let name: String?
    let url: String?
    let position: [Float]?
    let scale: [Float]?
    let rotation: [Float]?
    let visible: Bool?

    enum CodingKeys: String, CodingKey { case id, name, url, position, scale, rotation, visible }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id       = (try? c.decode(String.self, forKey: .id)) ?? UUID().uuidString
        name     = try? c.decodeIfPresent(String.self, forKey: .name)
        url      = try? c.decodeIfPresent(String.self, forKey: .url)
        position = try? c.decodeIfPresent([Float].self, forKey: .position)
        scale    = try? c.decodeIfPresent([Float].self, forKey: .scale)
        rotation = try? c.decodeIfPresent([Float].self, forKey: .rotation)
        visible  = try? c.decodeIfPresent(Bool.self, forKey: .visible)
    }
}

// MARK: - Adnotare
struct Annotation: Identifiable, Codable {
    let id: String
    let title: String
    let text: String?
    let position: [Float]?
    let normal: [Float]?
    let ttsVoice: String?
    let modelId: String?
    let color: String?
    let isIntroAudio: Bool?
    let animationId: String?
    let media: [MediaItem]

    enum CodingKeys: String, CodingKey {
        case id, title, text, position, normal, ttsVoice, modelId, color, isIntroAudio, animationId, media
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id           = (try? c.decode(String.self, forKey: .id)) ?? UUID().uuidString
        title        = (try? c.decode(String.self, forKey: .title)) ?? "Adnotare"
        text         = try? c.decodeIfPresent(String.self, forKey: .text)
        position     = try? c.decodeIfPresent([Float].self, forKey: .position)
        normal       = try? c.decodeIfPresent([Float].self, forKey: .normal)
        ttsVoice     = try? c.decodeIfPresent(String.self, forKey: .ttsVoice)
        modelId      = try? c.decodeIfPresent(String.self, forKey: .modelId)
        color        = try? c.decodeIfPresent(String.self, forKey: .color)
        isIntroAudio = try? c.decodeIfPresent(Bool.self, forKey: .isIntroAudio)
        animationId  = try? c.decodeIfPresent(String.self, forKey: .animationId)

        // MEDIA: format NOU = listă; format VECHI = obiect unic — suportăm ambele
        if let list = try? c.decodeIfPresent([MediaItem].self, forKey: .media) {
            media = list.filter { $0.type != "none" && !$0.data.isEmpty && $0.data != "[File Pending]" }
        } else if let legacy = try? c.decodeIfPresent(LegacyMedia.self, forKey: .media),
                  let d = legacy.data, !d.isEmpty,
                  let t = legacy.type, t != "none" {
            media = [MediaItem(type: t, data: d)]
        } else {
            media = []
        }
    }

    // Poziția 3D locală pe model
    var position3D: SIMD3<Float> {
        guard let p = position, p.count >= 3 else { return SIMD3<Float>(0, 0.2, 0) }
        return SIMD3<Float>(p[0], p[1], p[2])
    }

    var normal3D: SIMD3<Float> {
        guard let n = normal, n.count >= 3 else { return SIMD3<Float>(0, 1, 0) }
        return SIMD3<Float>(n[0], n[1], n[2])
    }

    // Primul audio atașat (dacă există, înlocuiește TTS-ul)
    var audioItem: MediaItem? { media.first(where: { $0.isAudio }) }
    var hasAudio: Bool { audioItem != nil }

    // Compatibilitate cu codul vechi
    var hasLink: Bool { media.contains(where: { $0.isLink }) }
}

// MARK: - Task-uri (cu timeLimit tolerant: Int SAU String în DB)
struct LocalizationTask: Identifiable, Codable {
    let id: String
    let title: String
    let annotationId: String
}

struct IdentificationTask: Identifiable, Codable {
    let id: String
    let question: String
    let annotationId: String
}

struct QuizTask: Identifiable, Codable {
    let id: String
    let question: String
    let timeLimit: Int?
    let answers: [QuizAnswer]

    enum CodingKeys: String, CodingKey { case id, question, timeLimit, answers }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id       = (try? c.decode(String.self, forKey: .id)) ?? UUID().uuidString
        question = (try? c.decode(String.self, forKey: .question)) ?? "Quiz"
        answers  = (try? c.decodeIfPresent([QuizAnswer].self, forKey: .answers)) ?? []
        // În DB timeLimit poate veni ca Int SAU ca String ("60")
        if let n = try? c.decodeIfPresent(Int.self, forKey: .timeLimit) {
            timeLimit = n
        } else if let s = try? c.decodeIfPresent(String.self, forKey: .timeLimit) {
            timeLimit = Int(s)
        } else {
            timeLimit = nil
        }
    }
}

struct QuizAnswer: Codable {
    let text: String
    let isCorrect: Bool
}

// MARK: - Experiența
struct Experience: Identifiable, Codable {
    let id: String
    let title: String
    let model_url: String?
    let model_url_ios: String?
    let bg_color: String?
    let bg_360_url: String?
    let thumbnail_url: String?
    let created_at: String?
    let created_by: String?
    let completions_count: Int?
    let models: [Model3D]?
    let annotations: [Annotation]?
    let localizations: [LocalizationTask]?
    let identifications: [IdentificationTask]?
    let quizzes: [QuizTask]?

    enum CodingKeys: String, CodingKey {
        case id, title, model_url, model_url_ios, bg_color, bg_360_url, thumbnail_url
        case created_at, created_by, completions_count
        case models, annotations, localizations, identifications, quizzes
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id    = try c.decode(String.self, forKey: .id)
        title = (try? c.decode(String.self, forKey: .title)) ?? "Experiență"
        model_url         = try? c.decodeIfPresent(String.self, forKey: .model_url)
        model_url_ios     = try? c.decodeIfPresent(String.self, forKey: .model_url_ios)
        bg_color          = try? c.decodeIfPresent(String.self, forKey: .bg_color)
        bg_360_url        = try? c.decodeIfPresent(String.self, forKey: .bg_360_url)
        thumbnail_url     = try? c.decodeIfPresent(String.self, forKey: .thumbnail_url)
        created_at        = try? c.decodeIfPresent(String.self, forKey: .created_at)
        created_by        = try? c.decodeIfPresent(String.self, forKey: .created_by)
        completions_count = try? c.decodeIfPresent(Int.self, forKey: .completions_count)
        models            = try? c.decodeIfPresent([Model3D].self, forKey: .models)
        annotations       = try? c.decodeIfPresent([Annotation].self, forKey: .annotations)
        localizations     = try? c.decodeIfPresent([LocalizationTask].self, forKey: .localizations)
        identifications   = try? c.decodeIfPresent([IdentificationTask].self, forKey: .identifications)
        quizzes           = try? c.decodeIfPresent([QuizTask].self, forKey: .quizzes)
    }

    // ============ HELPERS ============

    /// URL-ul GLB principal: model_url (legacy) SAU primul model vizibil din lista nouă
    var primaryModelURL: String? {
        if let u = model_url, !u.isEmpty { return u }
        return models?.first(where: { ($0.visible ?? true) && ($0.url?.isEmpty == false) })?.url
    }

    var has360: Bool { (bg_360_url ?? "").isEmpty == false }
    var hasModel: Bool { primaryModelURL != nil }

    var modelsCount: Int {
        if let m = models, !m.isEmpty { return m.count }
        return model_url != nil ? 1 : 0
    }

    var taskCount: Int {
        (localizations?.count ?? 0) + (identifications?.count ?? 0) + (quizzes?.count ?? 0)
    }

    var createdDate: Date? { uoParseDate(created_at) }

    /// Publicată în ultimele 7 zile
    var isNew: Bool {
        guard let d = createdDate else { return false }
        return Date().timeIntervalSince(d) < 7 * 86400
    }
}

// MARK: - Parsare dată ISO (Supabase: fracțiuni de secundă variabile)
func uoParseDate(_ s: String?) -> Date? {
    guard let s = s else { return nil }
    let iso = ISO8601DateFormatter()
    iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let d = iso.date(from: s) { return d }
    iso.formatOptions = [.withInternetDateTime]
    if let d = iso.date(from: s) { return d }
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US_POSIX")
    f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSZZZZZ"
    return f.date(from: s)
}