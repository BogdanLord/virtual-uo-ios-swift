import SwiftUI
import RealityKit
import ARKit
import GLTFKit2

struct ARExperienceView: View {
    let experience: Experience
    @Environment(\.dismiss) private var dismiss

    @State private var stage: ARStage = .scanning
    @State private var statusDetail = ""
    @State private var errorText: String?
    @State private var selectedAnnotation: Annotation?
    @State private var sidebarOpen = false

    // Task state
    @State private var taskMenuOpen = false
    @State private var activeTask: TaskKind?
    @State private var progress: [String: ProgressService.TaskStatus] = [:]
    @State private var feedback: (success: Bool, message: String)?
    @State private var localizationTaskActive: LocalizationTask?

    private let accent = Color(red: 0.0, green: 1.0, blue: 0.53)
    private let taskAccent = Color(red: 0.0, green: 0.67, blue: 1.0)

    enum ARStage {
        case scanning, readyToPlace, downloading, placed, failed
    }

    private var allTasks: [TaskKind] {
        var result: [TaskKind] = []
        (experience.localizations ?? []).forEach { result.append(.localization($0)) }
        (experience.identifications ?? []).forEach { result.append(.identification($0)) }
        (experience.quizzes ?? []).forEach { result.append(.quiz($0)) }
        return result
    }

    var body: some View {
        ZStack {
            arLayer
            uiLayer
            sidebarLayer
            taskLayer
            sheetLayer
            feedbackLayer
        }
        .navigationBarHidden(true)
        .statusBarHidden(true)
        .onAppear {
            AppDelegate.orientationLock = .landscape
            UIDevice.current.setValue(
                UIInterfaceOrientation.landscapeRight.rawValue,
                forKey: "orientation"
            )
            progress = ProgressService.shared.getProgress(experienceId: experience.id)
        }
        .onDisappear {
            AppDelegate.orientationLock = .all
            TTSService.shared.stop()
        }
    }

    // MARK: - Layers

    private var arLayer: some View {
        ARViewContainer(
            experience: experience,
            stage: $stage,
            statusDetail: $statusDetail,
            errorText: $errorText,
            selectedAnnotation: $selectedAnnotation,
            onAnnotationTapped: { ann in
                handleAnnotationTap(ann)
            }
        )
        .ignoresSafeArea()
    }

    private var uiLayer: some View {
        VStack {
            topBar
            Spacer()
            if selectedAnnotation == nil && !sidebarOpen && !taskMenuOpen
                && activeTask == nil {
                bottomStatus
            }
        }
    }

    @ViewBuilder
    private var sidebarLayer: some View {
        if stage == .placed {
            AnnotationSidebar(
                annotations: experience.annotations ?? [],
                onSelect: { ann in
                    withAnimation { sidebarOpen = false }
                    selectedAnnotation = ann
                },
                isOpen: $sidebarOpen
            )
        }
    }

    @ViewBuilder
    private var taskLayer: some View {
        if stage == .placed {
            TaskMenu(
                tasks: allTasks,
                progress: progress,
                onSelect: { task in
                    withAnimation { taskMenuOpen = false }
                    startTask(task)
                },
                isOpen: $taskMenuOpen
            )
        }

        if let task = activeTask {
            ActiveTaskCard(
                task: task,
                annotations: experience.annotations ?? [],
                onPass: { completeTask(task, success: true) },
                onFail: { completeTask(task, success: false) },
                onClose: { activeTask = nil; localizationTaskActive = nil }
            )
        }
    }

    @ViewBuilder
    private var sheetLayer: some View {
        if let ann = selectedAnnotation {
            AnnotationSheet(annotation: ann) {
                TTSService.shared.stop()
                selectedAnnotation = nil
            }
        }
    }

    @ViewBuilder
    private var feedbackLayer: some View {
        if let fb = feedback {
            TaskFeedback(isSuccess: fb.success, message: fb.message)
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack {
            closeButton
            Spacer()
            titleBadge
            Spacer()
            if stage == .placed {
                taskButton
                sidebarButton
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    private var closeButton: some View {
        Button {
            TTSService.shared.stop()
            dismiss()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "xmark")
                Text("Inchide")
            }
            .font(.system(size: 14, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.red.opacity(0.85))
            .clipShape(Capsule())
        }
    }

    private var titleBadge: some View {
        Text(experience.title)
            .font(.system(size: 12, weight: .bold))
            .foregroundColor(.white)
            .lineLimit(1)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
    }

    private var taskButton: some View {
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                sidebarOpen = false
                taskMenuOpen.toggle()
            }
        } label: {
            Image(systemName: "checklist")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
                .padding(12)
                .background(taskAccent)
                .clipShape(Circle())
        }
    }

    private var sidebarButton: some View {
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                taskMenuOpen = false
                sidebarOpen.toggle()
            }
        } label: {
            Image(systemName: "list.bullet")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.black)
                .padding(12)
                .background(accent)
                .clipShape(Circle())
        }
    }

    private var bottomStatus: some View {
        Group {
            if let err = errorText {
                Text("Eroare: \(err)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(Color.red.opacity(0.85))
                    .clipShape(Capsule())
            } else {
                HStack(spacing: 8) {
                    if stage == .downloading {
                        ProgressView().tint(accent).scaleEffect(0.8)
                    }
                    Text(statusText)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(accent.opacity(0.3), lineWidth: 1))
            }
        }
        .padding(.bottom, 24)
    }

    private var statusText: String {
        switch stage {
        case .scanning: return "Misca telefonul ca sa scanezi podeaua"
        case .readyToPlace: return "Atinge ecranul ca sa plasezi modelul"
        case .downloading: return "Se incarca... \(statusDetail)"
        case .placed:
            if localizationTaskActive != nil {
                return "Atinge eticheta corecta pe model"
            }
            return "Atinge etichetele verzi pentru detalii"
        case .failed: return "A aparut o problema"
        }
    }

    // MARK: - Task logic

    private func startTask(_ task: TaskKind) {
        selectedAnnotation = nil
        if case .localization(let locTask) = task {
            // Pentru localizare: nu aratam card, asteptam tap pe adnotare
            localizationTaskActive = locTask
            activeTask = nil
        } else {
            // Identificare / quiz: aratam card
            localizationTaskActive = nil
            activeTask = task
        }
    }

    private func handleAnnotationTap(_ ann: Annotation) {
        // Daca e activ un task de localizare, verificam
        if let locTask = localizationTaskActive {
            let success = (ann.id == locTask.annotationId)
            completeTask(.localization(locTask), success: success)
            localizationTaskActive = nil
            return
        }
        // Altfel, deschidem adnotarea normal
        selectedAnnotation = ann
    }

    private func completeTask(_ task: TaskKind, success: Bool) {
        // Salvam progresul
        ProgressService.shared.setStatus(
            success ? .success : .failed,
            taskId: task.id,
            experienceId: experience.id
        )
        progress = ProgressService.shared.getProgress(experienceId: experience.id)

        // Haptic
        let gen = UINotificationFeedbackGenerator()
        gen.notificationOccurred(success ? .success : .error)

        // Inchide card
        activeTask = nil

        // Arata feedback
        feedback = (success, success ? "Corect!" : "Gresit!")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            feedback = nil
        }
    }
}

struct ARViewContainer: UIViewRepresentable {
    let experience: Experience
    @Binding var stage: ARExperienceView.ARStage
    @Binding var statusDetail: String
    @Binding var errorText: String?
    @Binding var selectedAnnotation: Annotation?
    var onAnnotationTapped: (Annotation) -> Void

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)

        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal]
        config.environmentTexturing = .automatic
        config.worldAlignment = .gravity

        arView.session.run(config)
        arView.session.delegate = context.coordinator
        context.coordinator.arView = arView

        let tap = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleTap(_:))
        )
        arView.addGestureRecognizer(tap)

        let pinch = UIPinchGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handlePinch(_:))
        )
        arView.addGestureRecognizer(pinch)

        let rotation = UIRotationGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleRotation(_:))
        )
        arView.addGestureRecognizer(rotation)

        pinch.delegate = context.coordinator
        rotation.delegate = context.coordinator

        context.coordinator.startUpdateLoop()
        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, ARSessionDelegate, UIGestureRecognizerDelegate {
        var parent: ARViewContainer
        weak var arView: ARView?
        var hasFoundPlane = false
        var modelPlaced = false

        var transformEntity: Entity?
        var currentScale: Float = 1.0
        var currentRotationY: Float = 0.0
        var baseScale: Float = 1.0

        var annotationEntities: [ObjectIdentifier: Annotation] = [:]
        var billboardEntities: [Entity] = []
        var pulseEntities: [ModelEntity] = []
        var displayLink: CADisplayLink?
        var pulseTime: Float = 0

        init(_ parent: ARViewContainer) {
            self.parent = parent
        }

        func gestureRecognizer(
            _ g: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith o: UIGestureRecognizer
        ) -> Bool { true }

        func startUpdateLoop() {
            displayLink = CADisplayLink(target: self, selector: #selector(onFrame))
            displayLink?.add(to: .main, forMode: .common)
        }

        @objc func onFrame() {
            guard let arView = arView else { return }
            let camPos = arView.cameraTransform.translation
            for label in billboardEntities {
                let labelPos = label.position(relativeTo: nil)
                let dir = camPos - labelPos
                let angle = atan2(dir.x, dir.z)
                label.setOrientation(
                    simd_quatf(angle: angle, axis: SIMD3<Float>(0, 1, 0)),
                    relativeTo: nil
                )
            }
            pulseTime += 0.05
            let pulse = 1.0 + 0.4 * sin(pulseTime)
            for dot in pulseEntities {
                dot.scale = SIMD3<Float>(repeating: pulse)
            }
        }

        func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
            for anchor in anchors where anchor is ARPlaneAnchor {
                if !hasFoundPlane {
                    hasFoundPlane = true
                    DispatchQueue.main.async {
                        self.parent.stage = .readyToPlace
                    }
                }
            }
        }

        func session(_ session: ARSession, didFailWithError error: Error) {
            DispatchQueue.main.async {
                self.parent.errorText = error.localizedDescription
                self.parent.stage = .failed
            }
        }

        @objc func handleTap(_ sender: UITapGestureRecognizer) {
            guard let arView = arView else { return }
            let loc = sender.location(in: arView)

            if modelPlaced {
                if let hit = arView.entity(at: loc) {
                    var e: Entity? = hit
                    while let cur = e {
                        if let ann = annotationEntities[ObjectIdentifier(cur)] {
                            let gen = UIImpactFeedbackGenerator(style: .medium)
                            gen.impactOccurred()
                            DispatchQueue.main.async {
                                self.parent.onAnnotationTapped(ann)
                            }
                            return
                        }
                        e = cur.parent
                    }
                }
                return
            }

            guard parent.stage == .readyToPlace else { return }

            let r1 = arView.raycast(from: loc, allowing: .existingPlaneGeometry, alignment: .horizontal)
            let result = r1.first ?? arView.raycast(from: loc, allowing: .estimatedPlane, alignment: .horizontal).first

            guard let res = result else {
                DispatchQueue.main.async { self.parent.statusDetail = "indreapta spre podea" }
                return
            }

            modelPlaced = true
            let gen = UIImpactFeedbackGenerator(style: .heavy)
            gen.impactOccurred()

            let arAnchor = ARAnchor(name: "modelAnchor", transform: res.worldTransform)
            arView.session.add(anchor: arAnchor)
            let anchorEntity = AnchorEntity(anchor: arAnchor)
            arView.scene.addAnchor(anchorEntity)

            DispatchQueue.main.async { self.parent.stage = .downloading }
            Task { await self.loadGLBModel(anchorEntity: anchorEntity) }
        }

        @objc func handlePinch(_ sender: UIPinchGestureRecognizer) {
            guard transformEntity != nil else { return }
            if sender.state == .began { baseScale = currentScale }
            if sender.state == .changed || sender.state == .ended {
                currentScale = min(max(baseScale * Float(sender.scale), 0.2), 5.0)
                applyTransform()
            }
        }

        @objc func handleRotation(_ sender: UIRotationGestureRecognizer) {
            guard transformEntity != nil else { return }
            if sender.state == .changed || sender.state == .ended {
                currentRotationY -= Float(sender.rotation)
                sender.rotation = 0
                applyTransform()
            }
        }

        func applyTransform() {
            guard let e = transformEntity else { return }
            e.transform.scale = SIMD3<Float>(repeating: currentScale)
            e.transform.rotation = simd_quatf(angle: currentRotationY, axis: SIMD3<Float>(0, 1, 0))
        }

        @MainActor
        func loadGLBModel(anchorEntity: AnchorEntity) async {
            guard let glbURLString = parent.experience.model_url else {
                parent.errorText = "Nu exista model GLB"
                parent.stage = .failed
                return
            }
            do {
                parent.statusDetail = "descarcare..."
                let localURL = try await ARModelDownloader.shared.downloadModel(from: glbURLString)
                parent.statusDetail = "procesare..."
                let asset = try await GLTFAsset(url: localURL)
                let sceneSource = GLTFSCNSceneSource(asset: asset)
                guard let scnScene = sceneSource.defaultScene else {
                    parent.errorText = "Scena GLB goala"
                    parent.stage = .failed
                    return
                }
                let rawModel = try await convertToRealityKit(scnScene: scnScene)

                let bounds = rawModel.visualBounds(relativeTo: nil)
                let center = bounds.center
                let maxDim = max(bounds.extents.x, max(bounds.extents.y, bounds.extents.z))
                let normalizeScale = maxDim > 0 ? (Float(0.3) / maxDim) : 1.0

                let innerEntity = Entity()
                rawModel.position = SIMD3<Float>(-center.x, -center.y, -center.z)
                innerEntity.addChild(rawModel)

                let transformEntity = Entity()
                transformEntity.addChild(innerEntity)

                addAnnotations(to: transformEntity)

                let modelHeight = bounds.extents.y * normalizeScale
                let baseEntity = Entity()
                baseEntity.position = SIMD3<Float>(0, modelHeight / 2.0, 0)
                baseEntity.addChild(transformEntity)

                self.transformEntity = transformEntity
                self.currentScale = normalizeScale
                self.baseScale = normalizeScale
                applyTransform()

                anchorEntity.addChild(baseEntity)
                parent.stage = .placed
            } catch {
                parent.errorText = error.localizedDescription
                parent.stage = .failed
            }
        }

        func addAnnotations(to parentEntity: Entity) {
            guard let annotations = parent.experience.annotations else { return }

            for ann in annotations {
                let pos = ann.position3D
                let lineHeight: Float = 0.13

                let container = Entity()
                container.position = pos

                let dotMesh = MeshResource.generateSphere(radius: 0.005)
                var dotMat = UnlitMaterial()
                dotMat.color = .init(tint: UIColor(red: 0, green: 1, blue: 0.53, alpha: 1))
                let dot = ModelEntity(mesh: dotMesh, materials: [dotMat])
                container.addChild(dot)

                let haloMesh = MeshResource.generateSphere(radius: 0.011)
                var haloMat = UnlitMaterial()
                haloMat.color = .init(tint: UIColor(red: 0, green: 1, blue: 0.53, alpha: 0.3))
                let halo = ModelEntity(mesh: haloMesh, materials: [haloMat])
                container.addChild(halo)
                pulseEntities.append(halo)

                let lineMesh = MeshResource.generateBox(
                    size: SIMD3<Float>(0.0018, lineHeight, 0.0018)
                )
                var lineMat = UnlitMaterial()
                lineMat.color = .init(tint: UIColor(red: 0, green: 1, blue: 0.53, alpha: 0.85))
                let line = ModelEntity(mesh: lineMesh, materials: [lineMat])
                line.position = SIMD3<Float>(0, lineHeight / 2, 0)
                container.addChild(line)

                let labelText = MeshResource.generateText(
                    ann.title,
                    extrusionDepth: 0.001,
                    font: .systemFont(ofSize: 0.032, weight: .bold),
                    containerFrame: .zero,
                    alignment: .center,
                    lineBreakMode: .byTruncatingTail
                )
                var textMat = UnlitMaterial()
                textMat.color = .init(tint: .white)
                let textEntity = ModelEntity(mesh: labelText, materials: [textMat])
                let tb = textEntity.visualBounds(relativeTo: nil)
                textEntity.position = SIMD3<Float>(-tb.extents.x / 2, -tb.extents.y / 2, 0.001)

                let bgW = tb.extents.x + 0.035
                let bgH = tb.extents.y + 0.025
                let bgMesh = MeshResource.generateBox(
                    size: SIMD3<Float>(bgW, bgH, 0.002),
                    cornerRadius: 0.008
                )
                var bgMat = UnlitMaterial()
                bgMat.color = .init(tint: UIColor(red: 0.02, green: 0.06, blue: 0.04, alpha: 0.92))
                let bg = ModelEntity(mesh: bgMesh, materials: [bgMat])

                let borderMesh = MeshResource.generateBox(
                    size: SIMD3<Float>(bgW + 0.004, bgH + 0.004, 0.001),
                    cornerRadius: 0.009
                )
                var borderMat = UnlitMaterial()
                borderMat.color = .init(tint: UIColor(red: 0, green: 1, blue: 0.53, alpha: 0.9))
                let border = ModelEntity(mesh: borderMesh, materials: [borderMat])
                border.position = SIMD3<Float>(0, 0, -0.001)

                let labelGroup = Entity()
                labelGroup.position = SIMD3<Float>(0, lineHeight + 0.025, 0)
                labelGroup.addChild(border)
                labelGroup.addChild(bg)
                labelGroup.addChild(textEntity)

                bg.generateCollisionShapes(recursive: false)
                border.generateCollisionShapes(recursive: false)

                container.addChild(labelGroup)
                parentEntity.addChild(container)

                billboardEntities.append(labelGroup)
                annotationEntities[ObjectIdentifier(bg)] = ann
                annotationEntities[ObjectIdentifier(border)] = ann
                annotationEntities[ObjectIdentifier(textEntity)] = ann
                annotationEntities[ObjectIdentifier(labelGroup)] = ann
            }
        }

        @MainActor
        func convertToRealityKit(scnScene: SCNScene) async throws -> ModelEntity {
            let tempDir = FileManager.default.temporaryDirectory
            let tempUSDZ = tempDir.appendingPathComponent("conv_\(UUID().uuidString).usdz")
            let ok = scnScene.write(to: tempUSDZ, options: nil, delegate: nil, progressHandler: nil)
            guard ok else { throw ConversionError.exportFailed }
            let entity = try await ModelEntity(contentsOf: tempUSDZ)
            try? FileManager.default.removeItem(at: tempUSDZ)
            return entity
        }
    }
}

enum ConversionError: LocalizedError {
    case exportFailed
    var errorDescription: String? {
        switch self {
        case .exportFailed: return "Conversia GLB->USDZ a esuat"
        }
    }
}
