@'
import Foundation

struct Experience: Identifiable, Codable {
    let id: Int
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

struct Annotation: Identifiable, Codable {
    let id: String
    let title: String
    let text: String?
    let position: [Float]?

    var position3D: SIMD3<Float> {
        guard let p = position, p.count >= 3 else {
            return SIMD3<Float>(0, 0.2, 0)
        }
        return SIMD3<Float>(p[0], p[1], p[2])
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
'@ | Out-File -Encoding utf8 VirtualUO\Models\Experience.swift