import Foundation

struct Experience: Identifiable, Codable {
    let id: String
    let title: String
    let model_url: String?
    let model_url_ios: String?
    let bg_color: String?
    let created_at: String?
    let annotations: [Annotation]?
    let localizations: [LocalizationTask]?
    let identifications: [IdentificationTask]?
    let quizzes: [QuizTask]?
}

struct AnnotationMedia: Codable {
    let type: String       // "none", "image", "video", "link"
    let data: String?
}

struct Annotation: Identifiable, Codable {
    let id: String
    let title: String
    let text: String?
    let position: [Float]?
    let normal: [Float]?
    let media: AnnotationMedia?
    let ttsVoice: String?

    var position3D: SIMD3<Float> {
        guard let p = position, p.count >= 3 else {
            return SIMD3<Float>(0, 0.2, 0)
        }
        return SIMD3<Float>(p[0], p[1], p[2])
    }

    var normal3D: SIMD3<Float> {
        guard let n = normal, n.count >= 3 else {
            return SIMD3<Float>(0, 1, 0)
        }
        return SIMD3<Float>(n[0], n[1], n[2])
    }

    var hasLink: Bool {
        guard let media = media else { return false }
        return media.type == "link" && (media.data?.isEmpty == false)
    }

    var hasImage: Bool {
        guard let media = media else { return false }
        return media.type == "image" && (media.data?.isEmpty == false)
    }
}

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
}

struct QuizAnswer: Codable {
    let text: String
    let isCorrect: Bool
}
