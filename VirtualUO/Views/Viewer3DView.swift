import SwiftUI
import RealityKit
import GLTFKit2
import SceneKit

// ====================================================================
//  VIZIONARE 3D (non-AR) — v2 MULTI-MODEL
//  • încarcă TOATE modelele din lecție, cu poziția/scara/rotația
//    setate în editorul web (layout identic cu platforma)
//  • adnotările se atașează pe modelul lor (după modelId)
//  • rotire cu un deget, zoom cu pinch (toată scena, ca un tot unitar)
//  • buton FUNDAL 360° — IMPLICIT DEZACTIVAT
//  • intro audio + mute
// ====================================================================
struct Viewer3DView: View {
    let experience: Experience
    @Environment(\.dismiss) private var dismiss

    @State private var stage: ViewerStage = .loading
    @State private var loadingText = "Se încarcă..."
    @State private var errorText: String?
    @State private var selectedAnnotation: Annotation?
    @State private var sidebarOpen = false
    @State private var show360 = false        // IMPLICIT DEZACTIVAT
    @State private var loading360 = false
    @State private var muted = false

    enum ViewerStage { case loading, ready, failed }

    var body: some View {
        ZStack {
            Color(uiColor: UIColor(hex: experience.bg_color ?? "#0d1628"))
                .ignoresSafeArea()

            Viewer3DContainer(
                experience: experience,
                stage: $stage,
                loadingText: $loadingText,
                errorText: $errorText,
                show360: $show360,
                loading360: $loading360,
                onAnnotationTapped: { ann in
                    selectedAnnotation = ann
                }
            )
            .ignoresSafeArea()

            uiLayer

            if stage == .ready {
                AnnotationSidebar(
                    annotations: experience.annotations ?? [],
                    onSelect: { ann in
                        withAnimation { sidebarOpen = false }
                        selectedAnnotation = ann
                    },
                    isOpen: $sidebarOpen
                )
            }

            if let ann = selectedAnnotation {
                AnnotationSheet(annotation: ann) {
                    AudioService.shared.stop()
                    TTSService.shared.stop()
                    selectedAnnotation = nil
                }
            }
        }
        .navigationBarHidden(true)
        .statusBarHidden(true)
        .onAppear { playIntroIfAny() }
        .onDisappear { AudioService.shared.silenceAll() }
    }

    // MARK: - UI peste scenă
    private var uiLayer: some View {
        VStack {
            HStack(spacing: 10) {
                Button {
                    AudioService.shared.silenceAll()
                    dismiss()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "xmark")
                        Text("Închide")
                    }
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(UO.red.opacity(0.85))
                    .clipShape(Capsule())
                }

                Spacer()

                Text(experience.title)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())

                Spacer()

                // MUTE — oprește tot sunetul
                circleButton(
                    icon: muted ? "speaker.slash.fill" : "speaker.wave.2.fill",
                    bg: muted ? UO.red : Color.white.opacity(0.15),
                    fg: .white
                ) {
                    muted.toggle()
                    if muted { AudioService.shared.silenceAll() }
                }

                // FUNDAL 360° — implicit OFF
                if experience.has360 {
                    circleButton(
                        icon: "globe.americas.fill",
                        bg: show360 ? UO.purple : Color.white.opacity(0.15),
                        fg: show360 ? .black : .white
                    ) {
                        show360.toggle()
                    }
                }

                if stage == .ready {
                    circleButton(icon: "list.bullet", bg: UO.green, fg: .black) {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            sidebarOpen.toggle()
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

            Spacer()

            if stage == .loading {
                statusPill(text: loadingText, spinning: true)
            } else if stage == .failed {
                statusPill(text: errorText ?? "Eroare la încărcare", spinning: false, color: UO.red)
            } else if loading360 {
                statusPill(text: "Se încarcă fundalul 360°...", spinning: true)
            } else if selectedAnnotation == nil && !sidebarOpen {
                statusPill(text: "Rotește cu un deget · Zoom cu două degete", spinning: false)
            }
        }
    }

    private func circleButton(icon: String, bg: Color, fg: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(fg)
                .padding(11)
                .background(bg)
                .clipShape(Circle())
        }
    }

    private func statusPill(text: String, spinning: Bool, color: Color = .white) -> some View {
        HStack(spacing: 10) {
            if spinning { ProgressView().tint(UO.teal) }
            Text(text)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(color.opacity(0.9))
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .padding(.bottom, 26)
    }

    private func playIntroIfAny() {
        guard !muted,
              let intro = experience.annotations?.first(where: { ($0.isIntroAudio ?? false) && $0.hasAudio }),
              let audio = intro.audioItem else { return }
        AudioService.shared.play(audio.data)
    }
}

// ====================================================================
//  CONTAINERUL RealityKit
// ====================================================================
struct Viewer3DContainer: UIViewRepresentable {
    let experience: Experience
    @Binding var stage: Viewer3DView.ViewerStage
    @Binding var loadingText: String
    @Binding var errorText: String?
    @Binding var show360: Bool
    @Binding var loading360: Bool
    let onAnnotationTapped: (Annotation) -> Void

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero, cameraMode: .nonAR, automaticallyConfigureSession: false)
        arView.environment.background = .color(UIColor(hex: experience.bg_color ?? "#0d1628"))

        context.coordinator.arView = arView
        context.coordinator.setupCameraAndGestures()

        Task { await context.coordinator.loadModels() }
        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        context.coordinator.set360(enabled: show360)
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    // ================================================================
    @MainActor
    class Coordinator: NSObject {
        var parent: Viewer3DContainer
        weak var arView: ARView?

        private var worldAnchor: AnchorEntity?
        private var cameraEntity: PerspectiveCamera?

        /// pivot = ce rotește/scalează userul (toată scena, unitar)
        private var pivot: Entity?
        /// (eticheta, yaw-ul propriu al modelului) — pt. contra-rotație
        private var labelGroups: [(label: Entity, yaw: Float)] = []
        private var annotationEntities: [ObjectIdentifier: Annotation] = [:]

        private var rotY: Float = 0
        private var baseRotY: Float = 0
        private var currentScale: Float = 1
        private var baseScale: Float = 1
        private var camHeight: Float = 0.18
        private var baseCamHeight: Float = 0.18

        private var sphere360: ModelEntity?
        private var is360Visible = false

        init(_ parent: Viewer3DContainer) {
            self.parent = parent
        }

        // MARK: Cameră + gesturi
        func setupCameraAndGestures() {
            guard let arView = arView else { return }

            let anchor = AnchorEntity(world: .zero)
            arView.scene.addAnchor(anchor)
            worldAnchor = anchor

            let cam = PerspectiveCamera()
            cam.camera.fieldOfViewInDegrees = 50
            anchor.addChild(cam)
            cameraEntity = cam
            updateCamera()

            let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan))
            pan.maximumNumberOfTouches = 1
            arView.addGestureRecognizer(pan)

            let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch))
            arView.addGestureRecognizer(pinch)

            let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
            arView.addGestureRecognizer(tap)
        }

        private func updateCamera() {
            guard let cam = cameraEntity else { return }
            cam.look(at: SIMD3<Float>(0, 0, 0),
                     from: SIMD3<Float>(0, camHeight, 0.9),
                     relativeTo: nil)
        }

        // ============================================================
        //  ÎNCĂRCAREA TUTUROR MODELELOR
        //  Fiecare model primește transformările din editor; adnotările
        //  se atașează pe modelul lor (modelId) -> layout identic cu web.
        // ============================================================
        private struct ModelSpec {
            let id: String
            let url: String
            let position: SIMD3<Float>
            let scale: SIMD3<Float>
            let rotation: SIMD3<Float> // euler XYZ (radiani), ca în three.js
        }

        func loadModels() async {
            // 1) Construim lista de modele (format nou) sau fallback legacy
            var specs: [ModelSpec] = []

            if let models = parent.experience.models, !models.isEmpty {
                for m in models {
                    guard (m.visible ?? true), let u = m.url, !u.isEmpty else { continue }
                    specs.append(ModelSpec(
                        id: m.id,
                        url: u,
                        position: vec3(m.position, fallback: SIMD3<Float>(0, 0, 0)),
                        scale: vec3(m.scale, fallback: SIMD3<Float>(1, 1, 1)),
                        rotation: vec3(m.rotation, fallback: SIMD3<Float>(0, 0, 0))
                    ))
                }
            } else if let u = parent.experience.model_url, !u.isEmpty {
                specs.append(ModelSpec(
                    id: "__legacy__", url: u,
                    position: SIMD3<Float>(0, 0, 0),
                    scale: SIMD3<Float>(1, 1, 1),
                    rotation: SIMD3<Float>(0, 0, 0)
                ))
            }

            guard !specs.isEmpty else {
                parent.errorText = "Nu există modele 3D"
                parent.stage = .failed
                return
            }

            // 2) Pivot (gesturi) + sceneRoot (normalizare)
            let pivotEntity = Entity()
            worldAnchor?.addChild(pivotEntity)
            pivot = pivotEntity

            let sceneRoot = Entity()
            pivotEntity.addChild(sceneRoot)

            // 3) Descărcăm și plasăm fiecare model cu transformările lui
            var loaded: [(container: Entity, spec: ModelSpec)] = []

            for (idx, spec) in specs.enumerated() {
                parent.loadingText = "Se încarcă modelul \(idx + 1)/\(specs.count)..."
                do {
                    let localURL = try await ARModelDownloader.shared.downloadModel(from: spec.url)
                    let asset = try GLTFAsset(url: localURL)
                    let sceneSource = GLTFSCNSceneSource(asset: asset)
                    guard let scnScene = sceneSource.defaultScene else { continue }
                    let rawModel = try await convertToRealityKit(scnScene: scnScene)

                    // IMPORTANT: NU centram modelul — pivotul lui rămâne
                    // originea GLB-ului, exact ca în editorul web. Altfel
                    // pozițiile/adnotările din editor n-ar mai corespunde.
                    let container = Entity()
                    container.position = spec.position
                    container.scale = spec.scale
                    container.orientation = quatFromEulerXYZ(spec.rotation)
                    container.addChild(rawModel)

                    sceneRoot.addChild(container)
                    loaded.append((container, spec))
                } catch {
                    print("🔴 DROP model \(spec.id): \(error)")
                }
            }

            guard !loaded.isEmpty else {
                parent.errorText = "Niciun model nu a putut fi încărcat"
                parent.stage = .failed
                return
            }

            // 4) Normalizăm TOATĂ scena (păstrând layout-ul relativ):
            //    o aducem la ~0.5m și o centrăm în fața camerei
            let bounds = sceneRoot.visualBounds(relativeTo: nil)
            let maxDim = max(bounds.extents.x, max(bounds.extents.y, bounds.extents.z))
            let s: Float = maxDim > 0 ? (0.5 / maxDim) : 1.0
            let c = bounds.center
            sceneRoot.scale = SIMD3<Float>(repeating: s)
            sceneRoot.position = SIMD3<Float>(-c.x * s, -c.y * s, -c.z * s)

            // 5) Adnotările — FIECARE pe modelul ei (după modelId)
            let anns = parent.experience.annotations ?? []
            let loadedIds = Set(loaded.map { $0.spec.id })

            for (container, spec) in loaded {
                let mine = anns.filter { $0.modelId == spec.id }
                addAnnotations(mine, to: container, ownerYaw: spec.rotation.y)
            }
            // Adnotări orfane (lecții vechi fără modelId sau modele care n-au
            // putut fi încărcate) -> le punem pe primul model
            let orphans = anns.filter { a in
                guard let mid = a.modelId else { return true }
                return !loadedIds.contains(mid)
            }
            if let first = loaded.first {
                addAnnotations(orphans, to: first.container, ownerYaw: first.spec.rotation.y)
            }

            applyTransform()
            parent.stage = .ready
        }

        // Euler XYZ (three.js) -> quaternion
        private func quatFromEulerXYZ(_ e: SIMD3<Float>) -> simd_quatf {
            let qx = simd_quatf(angle: e.x, axis: SIMD3<Float>(1, 0, 0))
            let qy = simd_quatf(angle: e.y, axis: SIMD3<Float>(0, 1, 0))
            let qz = simd_quatf(angle: e.z, axis: SIMD3<Float>(0, 0, 1))
            return qx * qy * qz
        }

        private func vec3(_ arr: [Float]?, fallback: SIMD3<Float>) -> SIMD3<Float> {
            guard let a = arr, a.count >= 3,
                  a[0].isFinite, a[1].isFinite, a[2].isFinite else { return fallback }
            return SIMD3<Float>(a[0], a[1], a[2])
        }

        private func convertToRealityKit(scnScene: SCNScene) async throws -> ModelEntity {
            let tempDir = FileManager.default.temporaryDirectory
            let tempUSDZ = tempDir.appendingPathComponent("viewer_\(UUID().uuidString).usdz")
            let ok = scnScene.write(to: tempUSDZ, options: nil, delegate: nil, progressHandler: nil)
            guard ok else { throw ConversionError.exportFailed }
            let entity = try await ModelEntity(contentsOf: tempUSDZ)
            try? FileManager.default.removeItem(at: tempUSDZ)
            return entity
        }

        // MARK: Pini de adnotare (pe modelul lor, în coordonate locale)
        private func addAnnotations(_ annotations: [Annotation], to parentEntity: Entity, ownerYaw: Float) {
            for ann in annotations {
                let pos = ann.position3D
                let lineHeight: Float = 0.11

                let container = Entity()
                container.position = pos

                let dotMesh = MeshResource.generateSphere(radius: 0.006)
                var dotMat = UnlitMaterial()
                dotMat.color = .init(tint: UIColor(red: 0, green: 1, blue: 0.53, alpha: 1))
                let dot = ModelEntity(mesh: dotMesh, materials: [dotMat])
                dot.generateCollisionShapes(recursive: false)
                container.addChild(dot)
                annotationEntities[ObjectIdentifier(dot)] = ann

                let haloMesh = MeshResource.generateSphere(radius: 0.013)
                var haloMat = UnlitMaterial()
                haloMat.color = .init(tint: UIColor(red: 0, green: 1, blue: 0.53, alpha: 0.3))
                let halo = ModelEntity(mesh: haloMesh, materials: [haloMat])
                container.addChild(halo)

                let lineMesh = MeshResource.generateBox(size: SIMD3<Float>(0.0018, lineHeight, 0.0018))
                var lineMat = UnlitMaterial()
                lineMat.color = .init(tint: UIColor(red: 0, green: 1, blue: 0.53, alpha: 0.85))
                let line = ModelEntity(mesh: lineMesh, materials: [lineMat])
                line.position = SIMD3<Float>(0, lineHeight / 2, 0)
                container.addChild(line)

                let labelText = MeshResource.generateText(
                    ann.title,
                    extrusionDepth: 0.001,
                    font: .systemFont(ofSize: 0.03, weight: .bold),
                    containerFrame: .zero,
                    alignment: .center,
                    lineBreakMode: .byTruncatingTail
                )
                var textMat = UnlitMaterial()
                textMat.color = .init(tint: .white)
                let textEntity = ModelEntity(mesh: labelText, materials: [textMat])
                let tb = textEntity.visualBounds(relativeTo: nil)
                textEntity.position = SIMD3<Float>(-tb.extents.x / 2, -tb.extents.y / 2, 0.001)

                let bgW = tb.extents.x + 0.032
                let bgH = tb.extents.y + 0.022
                let bgMesh = MeshResource.generateBox(size: SIMD3<Float>(bgW, bgH, 0.002), cornerRadius: 0.008)
                var bgMat = UnlitMaterial()
                bgMat.color = .init(tint: UIColor(red: 0.02, green: 0.06, blue: 0.04, alpha: 0.92))
                let bg = ModelEntity(mesh: bgMesh, materials: [bgMat])

                let borderMesh = MeshResource.generateBox(size: SIMD3<Float>(bgW + 0.004, bgH + 0.004, 0.001), cornerRadius: 0.009)
                var borderMat = UnlitMaterial()
                borderMat.color = .init(tint: UIColor(red: 0, green: 1, blue: 0.53, alpha: 0.9))
                let border = ModelEntity(mesh: borderMesh, materials: [borderMat])
                border.position = SIMD3<Float>(0, 0, -0.001)

                let labelGroup = Entity()
                labelGroup.position = SIMD3<Float>(0, lineHeight + 0.022, 0)
                labelGroup.addChild(border)
                labelGroup.addChild(bg)
                labelGroup.addChild(textEntity)

                bg.generateCollisionShapes(recursive: false)
                border.generateCollisionShapes(recursive: false)

                container.addChild(labelGroup)
                parentEntity.addChild(container)

                labelGroups.append((labelGroup, ownerYaw))
                annotationEntities[ObjectIdentifier(bg)] = ann
                annotationEntities[ObjectIdentifier(border)] = ann
                annotationEntities[ObjectIdentifier(textEntity)] = ann
                annotationEntities[ObjectIdentifier(labelGroup)] = ann
            }
        }

        // MARK: Gesturi
        @objc func handlePan(_ sender: UIPanGestureRecognizer) {
            guard pivot != nil else { return }
            let tr = sender.translation(in: sender.view)
            if sender.state == .began {
                baseRotY = rotY
                baseCamHeight = camHeight
            }
            if sender.state == .changed || sender.state == .ended {
                rotY = baseRotY + Float(tr.x) * 0.012
                camHeight = min(max(baseCamHeight - Float(tr.y) * 0.0022, -0.2), 0.9)
                applyTransform()
                updateCamera()
            }
        }

        @objc func handlePinch(_ sender: UIPinchGestureRecognizer) {
            guard pivot != nil else { return }
            if sender.state == .began { baseScale = currentScale }
            if sender.state == .changed || sender.state == .ended {
                currentScale = min(max(baseScale * Float(sender.scale), 0.15), 8.0)
                applyTransform()
            }
        }

        @objc func handleTap(_ sender: UITapGestureRecognizer) {
            guard let arView = arView else { return }
            let loc = sender.location(in: arView)
            if let entity = arView.entity(at: loc) {
                var e: Entity? = entity
                while let cur = e {
                    if let ann = annotationEntities[ObjectIdentifier(cur)] {
                        let gen = UIImpactFeedbackGenerator(style: .medium)
                        gen.impactOccurred()
                        DispatchQueue.main.async { self.parent.onAnnotationTapped(ann) }
                        return
                    }
                    e = cur.parent
                }
            }
        }

        private func applyTransform() {
            guard let p = pivot else { return }
            p.transform.scale = SIMD3<Float>(repeating: currentScale)
            p.transform.rotation = simd_quatf(angle: rotY, axis: SIMD3<Float>(0, 1, 0))
            // Etichetele anulează rotația scenei + rotația proprie a modelului,
            // ca să rămână mereu cu fața spre cameră
            for (label, yaw) in labelGroups {
                label.orientation = simd_quatf(angle: -(rotY + yaw), axis: SIMD3<Float>(0, 1, 0))
            }
        }

        // Helper SINCRON: TextureResource.load e marcat "noasync" în Swift 6,
        // deci îl apelăm dintr-o funcție sincronă, nu direct din context async.
        nonisolated private static func loadTextureSync(_ url: URL) throws -> TextureResource {
            try TextureResource.load(contentsOf: url)
        }

        // MARK: Fundal 360° (sferă inversată texturată) — pornit DOAR manual
        func set360(enabled: Bool) {
            guard enabled != is360Visible else { return }
            is360Visible = enabled

            guard let arView = arView else { return }

            if !enabled {
                sphere360?.removeFromParent()
                arView.environment.background = .color(UIColor(hex: parent.experience.bg_color ?? "#0d1628"))
                return
            }

            if let sphere = sphere360 {
                worldAnchor?.addChild(sphere)
                return
            }

            guard let urlString = parent.experience.bg_360_url, let url = URL(string: urlString) else { return }
            parent.loading360 = true

            Task { @MainActor in
                do {
                    let (tempURL, _) = try await URLSession.shared.download(from: url)
                    let localURL = FileManager.default.temporaryDirectory
                        .appendingPathComponent("bg360_\(UUID().uuidString).jpg")
                    try? FileManager.default.removeItem(at: localURL)
                    try FileManager.default.moveItem(at: tempURL, to: localURL)

                    let texture = try Self.loadTextureSync(localURL)
                    var mat = UnlitMaterial()
                    mat.color = .init(tint: .white, texture: .init(texture))

                    let sphereMesh = MeshResource.generateSphere(radius: 18)
                    let sphere = ModelEntity(mesh: sphereMesh, materials: [mat])
                    sphere.scale = SIMD3<Float>(-1, 1, 1) // textura se vede din interior

                    self.sphere360 = sphere
                    if self.is360Visible { self.worldAnchor?.addChild(sphere) }
                    self.parent.loading360 = false
                } catch {
                    self.parent.loading360 = false
                    self.is360Visible = false
                    print("🔴 Eroare fundal 360: \(error)")
                }
            }
        }
    }
}