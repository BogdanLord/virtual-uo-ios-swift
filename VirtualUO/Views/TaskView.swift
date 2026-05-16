import SwiftUI

// MARK: - Tip generic de task pentru UI
enum TaskKind {
    case localization(LocalizationTask)
    case identification(IdentificationTask)
    case quiz(QuizTask)

    var id: String {
        switch self {
        case .localization(let t): return t.id
        case .identification(let t): return t.id
        case .quiz(let t): return t.id
        }
    }

    var label: String {
        switch self {
        case .localization(let t): return t.title
        case .identification(let t): return t.question
        case .quiz(let t): return t.question
        }
    }

    var icon: String {
        switch self {
        case .localization: return "scope"
        case .identification: return "magnifyingglass"
        case .quiz: return "questionmark.circle"
        }
    }

    var typeName: String {
        switch self {
        case .localization: return "Localizare"
        case .identification: return "Identificare"
        case .quiz: return "Quiz"
        }
    }
}

// MARK: - Meniu lateral cu lista task-urilor
struct TaskMenu: View {
    let tasks: [TaskKind]
    let progress: [String: ProgressService.TaskStatus]
    let onSelect: (TaskKind) -> Void
    @Binding var isOpen: Bool

    private let accent = Color(red: 0.0, green: 0.67, blue: 1.0)

    var body: some View {
        HStack(spacing: 0) {
            if isOpen {
                panel.transition(.move(edge: .leading))
            }
            Spacer()
        }
    }

    private var panel: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider().background(accent.opacity(0.2))
            progressBar
            list
        }
        .frame(width: 270)
        .background(
            ZStack {
                Color.black.opacity(0.7)
                LinearGradient(colors: [accent.opacity(0.06), .clear],
                               startPoint: .trailing, endPoint: .leading)
            }
            .background(.ultraThinMaterial)
        )
        .overlay(
            Rectangle().frame(width: 1).foregroundColor(accent.opacity(0.3)),
            alignment: .trailing
        )
    }

    private var header: some View {
        HStack {
            Image(systemName: "checklist")
                .font(.system(size: 18))
                .foregroundColor(accent)
            Text("SARCINI")
                .font(.system(size: 15, weight: .black))
                .foregroundColor(.white)
                .tracking(1)
            Spacer()
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    isOpen = false
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .padding(16)
    }

    private var completedCount: Int {
        tasks.filter { progress[$0.id] == .success }.count
    }

    private var progressBar: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Progres")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.6))
                Spacer()
                Text("\(completedCount)/\(tasks.count)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(accent)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.1))
                    Capsule()
                        .fill(accent)
                        .frame(width: tasks.isEmpty ? 0 :
                               geo.size.width * CGFloat(completedCount) / CGFloat(tasks.count))
                }
            }
            .frame(height: 6)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var list: some View {
        ScrollView {
            VStack(spacing: 8) {
                ForEach(Array(tasks.enumerated()), id: \.element.id) { index, task in
                    Button { onSelect(task) } label: {
                        taskRow(index: index, task: task)
                    }
                }
                if tasks.isEmpty {
                    Text("Nicio sarcina disponibila")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.4))
                        .padding(.top, 30)
                }
            }
            .padding(12)
        }
    }

    private func statusIcon(_ id: String) -> (String, Color) {
        switch progress[id] {
        case .success: return ("checkmark.circle.fill", Color(red: 0, green: 1, blue: 0.53))
        case .failed: return ("xmark.circle.fill", Color(red: 1, green: 0.3, blue: 0.3))
        default: return ("circle", Color.white.opacity(0.3))
        }
    }

    private func taskRow(index: Int, task: TaskKind) -> some View {
        let (iconName, iconColor) = statusIcon(task.id)
        return HStack(spacing: 10) {
            Image(systemName: task.icon)
                .font(.system(size: 16))
                .foregroundColor(accent)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(task.typeName)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(accent.opacity(0.8))
                Text(task.label)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            Spacer()
            Image(systemName: iconName)
                .font(.system(size: 18))
                .foregroundColor(iconColor)
        }
        .padding(10)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(accent.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Card task activ (identificare + quiz)
struct ActiveTaskCard: View {
    let task: TaskKind
    let annotations: [Annotation]
    let onPass: () -> Void
    let onFail: () -> Void
    let onClose: () -> Void

    @State private var idInput = ""
    @State private var quizSelections: [Bool] = []
    @State private var timeLeft = 0
    @State private var timer: Timer?
    @State private var appeared = false

    private let accent = Color(red: 0.0, green: 0.67, blue: 1.0)

    var body: some View {
        VStack {
            Spacer()
            card
                .offset(y: appeared ? 0 : 400)
                .opacity(appeared ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                appeared = true
            }
            setupTask()
        }
        .onDisappear { timer?.invalidate() }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            Text(task.label)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)

            switch task {
            case .localization:
                Text("Atinge eticheta corecta pe model.")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.6))
            case .identification:
                identificationContent
            case .quiz(let q):
                quizContent(q)
            }
        }
        .padding(20)
        .background(
            ZStack {
                Color.black.opacity(0.7)
                LinearGradient(colors: [accent.opacity(0.08), .clear],
                               startPoint: .top, endPoint: .bottom)
            }
            .background(.ultraThinMaterial)
        )
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(accent.opacity(0.4), lineWidth: 1)
        )
        .padding(.horizontal, 14)
        .padding(.bottom, 20)
        .shadow(color: accent.opacity(0.3), radius: 18)
    }

    private var header: some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: task.icon)
                Text(task.typeName.uppercased())
            }
            .font(.system(size: 12, weight: .black))
            .foregroundColor(accent)
            .tracking(1)
            Spacer()
            if case .quiz = task, timeLeft > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "clock.fill")
                    Text("\(timeLeft)s")
                }
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(timeLeft <= 10 ? .red : accent)
            }
            Button(action: closeWithAnim) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 26))
                    .foregroundColor(.white.opacity(0.4))
            }
        }
    }

    private var identificationContent: some View {
        VStack(spacing: 12) {
            TextField("", text: $idInput, prompt:
                Text("Scrie numele exact...").foregroundColor(.white.opacity(0.3)))
                .font(.system(size: 15))
                .foregroundColor(.white)
                .padding(12)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10)
                    .stroke(accent.opacity(0.4), lineWidth: 1))
            actionButton("VERIFICA") { checkIdentification() }
        }
    }

    private func quizContent(_ q: QuizTask) -> some View {
        VStack(spacing: 8) {
            ForEach(Array(q.answers.enumerated()), id: \.offset) { idx, answer in
                Button {
                    if idx < quizSelections.count {
                        quizSelections[idx].toggle()
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: (idx < quizSelections.count && quizSelections[idx])
                              ? "checkmark.square.fill" : "square")
                            .font(.system(size: 20))
                            .foregroundColor(accent)
                        Text(answer.text)
                            .font(.system(size: 14))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.leading)
                        Spacer()
                    }
                    .padding(10)
                    .background(Color.white.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            actionButton("TRIMITE RASPUNS") { checkQuiz(q) }
        }
    }

    private func actionButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .black))
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(accent)
                .clipShape(Capsule())
        }
        .padding(.top, 4)
    }

    private func setupTask() {
        if case .quiz(let q) = task {
            quizSelections = Array(repeating: false, count: q.answers.count)
            timeLeft = q.timeLimit ?? 60
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { t in
                if timeLeft > 0 {
                    timeLeft -= 1
                } else {
                    t.invalidate()
                    onFail()
                }
            }
        }
    }

    private func checkIdentification() {
        guard case .identification(let task) = task else { return }
        guard let target = annotations.first(where: { $0.id == task.annotationId }) else {
            onFail(); return
        }
        let normalized = idInput.trimmingCharacters(in: .whitespaces).lowercased()
        let correct = target.title.trimmingCharacters(in: .whitespaces).lowercased()
        normalized == correct ? onPass() : onFail()
    }

    private func checkQuiz(_ q: QuizTask) {
        timer?.invalidate()
        let allCorrect = q.answers.enumerated().allSatisfy { idx, answer in
            idx < quizSelections.count && answer.isCorrect == quizSelections[idx]
        }
        allCorrect ? onPass() : onFail()
    }

    private func closeWithAnim() {
        timer?.invalidate()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            appeared = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { onClose() }
    }
}

// MARK: - Feedback animat (Corect / Gresit)
struct TaskFeedback: View {
    let isSuccess: Bool
    let message: String
    @State private var scale: CGFloat = 0.3
    @State private var opacity: Double = 0

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: isSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 70))
                .foregroundColor(isSuccess
                    ? Color(red: 0, green: 1, blue: 0.53)
                    : Color(red: 1, green: 0.3, blue: 0.3))
            Text(message)
                .font(.system(size: 22, weight: .black))
                .foregroundColor(.white)
        }
        .padding(40)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .scaleEffect(scale)
        .opacity(opacity)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                scale = 1.0
                opacity = 1.0
            }
        }
    }
}
