import Foundation

// Salveaza progresul task-urilor local pe telefon
class ProgressService {
    static let shared = ProgressService()
    private init() {}

    enum TaskStatus: String {
        case notStarted, success, failed
    }

    private func key(for experienceId: String) -> String {
        return "task_progress_\(experienceId)"
    }

    // Returneaza dictionar [taskId: status]
    func getProgress(experienceId: String) -> [String: TaskStatus] {
        guard let raw = UserDefaults.standard.dictionary(forKey: key(for: experienceId)) as? [String: String] else {
            return [:]
        }
        var result: [String: TaskStatus] = [:]
        for (k, v) in raw {
            result[k] = TaskStatus(rawValue: v) ?? .notStarted
        }
        return result
    }

    func setStatus(_ status: TaskStatus, taskId: String, experienceId: String) {
        var raw = UserDefaults.standard.dictionary(forKey: key(for: experienceId)) as? [String: String] ?? [:]
        raw[taskId] = status.rawValue
        UserDefaults.standard.set(raw, forKey: key(for: experienceId))
    }

    func resetProgress(experienceId: String) {
        UserDefaults.standard.removeObject(forKey: key(for: experienceId))
    }
}
