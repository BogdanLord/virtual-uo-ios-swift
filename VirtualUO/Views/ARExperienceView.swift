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

    enum ARStage {
        case scanning, readyToPlace, downloading, placed, failed
    }

    var body: some View {
        ZStack {
            ARViewContainer(
                experience: experience,
                stage: $stage,
                statusDetail: $statusDetail,
                errorText: $errorText
            )
            .ignoresSafeArea()

            VStack {
                topBar
                Spacer()
                bottomStatus
            }
        }
        .navigationBarHidden(true)
        .statusBarHidden(true)
        .onAppear {
            AppDelegate.orientationLock = .landscape
            UIDevice.current.setValue(
                UIInterfaceOrientation.landscapeRight.rawValue,
                forKey: "orientation"
            )
        }
        .onDisappear {
            AppDelegate.orientationLock = .all
        }
    }

    private var topBar: some View {
        HStack {
            Button {
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

            Spacer()

            Text(experience.title)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
                .lineLimit(1)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
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
                Text(statusText)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
            }
        }
        .padding(.bottom, 24)
    }

    private var statusText: String {
        switch stage {
        case .scanning: return "Misca telefonul ca sa scanezi podeaua"
        case .readyToPlace: return "Atinge ecranul ca sa plasezi modelul"
        case .downloading: return "Se incarca modelul... \(statusDetail)"
        case .placed: return "Pinch = zoom, 2 degete = rotire"
        case .failed: return "A aparut o problema"
        }
    }
}

struct ARViewContainer: UIViewRepresentable {
    let experience: Experience
    @Binding var stage: ARExperienceView.ARStage
    @Binding var statusDetail: String
    @Binding var errorText: String?

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)

        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal]
        config.environmentTexturing = .automatic
        config.worldAlignment = .gravity

        arView.session.run(config)
        arView.session.delegate = context.coordinator
        context.coordinator.arView = arView

        // TAP - plasare model
        let tap = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleTap(_:))
        )
        arView.addGestureRecognizer(tap)

        // PINCH - zoom pe tot ecranul
        let pinch = UIPinchGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handlePinch(_:))
        )
        arView.addGestureRecognizer(pinch)

        // ROTATION - rotire cu 2 degete pe tot ecranul
        let rotation = UIRotationGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleRotation(_:))
        )
        arView.addGestureRecognizer(rotation)

        // Permitem pinch si rotation simultan
        pinch.delegate = context.coordinator
        rotation.delegate = context.coordinator

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

        // Entitatea pe care aplicam transformarile (rotire/scalare)
        var transformEntity: Entity?

        // Valorile curente de transformare
        var currentScale: Float = 1.0
        var currentRotationY: Float = 0.0
        var baseScale: Float = 1.0

        init(_ parent: ARViewContainer) {
            self.parent = parent
        }

        // Permite pinch + rotate simultan
        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
        ) -> Bool {
            return true
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

        // ── TAP: plaseaza modelul ──
        @objc func handleTap(_ sender: UITapGestureRecognizer) {
            guard let arView = arView, !modelPlaced,
                  parent.stage == .readyToPlace else { return }

            let tapLocation = sender.location(in: arView)

            let results = arView.raycast(
                from: tapLocation,
                allowing: .existingPlaneGeometry,
                alignment: .horizontal
            )
            let raycastResult = results.first ?? arView.raycast(
                from: tapLocation,
                allowing: .estimatedPlane,
                alignment: .horizontal
            ).first

            guard let result = raycastResult else {
                DispatchQueue.main.async {
                    self.parent.statusDetail = "indreapta spre podea"
                }
                return
            }

            modelPlaced = true

            // ARAnchor real - ARKit il tine fix in lume
            let arAnchor = ARAnchor(name: "modelAnchor", transform: result.worldTransform)
            arView.session.add(anchor: arAnchor)

            let anchorEntity = AnchorEntity(anchor: arAnchor)
            arView.scene.addAnchor(anchorEntity)

            DispatchQueue.main.async {
                self.parent.stage = .downloading
            }

            Task {
                await self.loadGLBModel(anchorEntity: anchorEntity)
            }
        }

        // ── PINCH: zoom pe tot ecranul ──
        @objc func handlePinch(_ sender: UIPinchGestureRecognizer) {
            guard let transformEntity = transformEntity else { return }

            if sender.state == .began {
                baseScale = currentScale
            }

            if sender.state == .changed || sender.state == .ended {
                // Scalam pornind de la baza, limitam intre 0.2x si 5x
                let newScale = baseScale * Float(sender.scale)
                currentScale = min(max(newScale, 0.2), 5.0)
                applyTransform()
            }
        }

        // ── ROTATION: rotire stanga-dreapta pe loc ──
        @objc func handleRotation(_ sender: UIRotationGestureRecognizer) {
            guard let transformEntity = transformEntity else { return }

            if sender.state == .changed || sender.state == .ended {
                // Rotim pe axa Y (verticala) - modelul se suceste pe loc
                currentRotationY -= Float(sender.rotation)
                sender.rotation = 0  // reset incremental
                applyTransform()
            }
        }

        // Aplica scalarea + rotirea pe entitate
        func applyTransform() {
            guard let entity = transformEntity else { return }
            entity.transform.scale = SIMD3<Float>(repeating: currentScale)
            entity.transform.rotation = simd_quatf(
                angle: currentRotationY,
                axis: SIMD3<Float>(0, 1, 0)
            )
        }

        // ── INCARCARE MODEL ──
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

                parent.statusDetail = "procesare GLB..."
                let asset = try await GLTFAsset(url: localURL)

                parent.statusDetail = "construire scena..."
                let sceneSource = GLTFSCNSceneSource(asset: asset)
                guard let scnScene = sceneSource.defaultScene else {
                    parent.errorText = "Scena GLB goala"
                    parent.stage = .failed
                    return
                }

                let rawModel = try await convertToRealityKit(scnScene: scnScene)

                // ═══ CENTRARE CORECTA ═══
                // 1. Calculam bounding box-ul real
                let bounds = rawModel.visualBounds(relativeTo: nil)
                let center = bounds.center
                let maxDim = max(bounds.extents.x, max(bounds.extents.y, bounds.extents.z))
                let normalizeScale = maxDim > 0 ? (Float(0.3) / maxDim) : 1.0

                // 2. innerEntity: muta geometria ca centrul ei sa fie la (0,0,0)
                //    Asta face ca scalarea/rotirea sa se faca FIX pe centru
                let innerEntity = Entity()
                rawModel.position = SIMD3<Float>(-center.x, -center.y, -center.z)
                innerEntity.addChild(rawModel)

                // 3. transformEntity: aici aplicam scale + rotatie (pivot = centru)
                let transformEntity = Entity()
                transformEntity.addChild(innerEntity)

                // 4. baseEntity: ridica modelul ca baza sa fie pe podea
                //    Inaltimea modelului dupa normalizare
                let modelHeight = bounds.extents.y * normalizeScale
                let baseEntity = Entity()
                baseEntity.position = SIMD3<Float>(0, modelHeight / 2.0, 0)
                baseEntity.addChild(transformEntity)

                // Salvam referinta + setam scala initiala
                self.transformEntity = transformEntity
                self.currentScale = normalizeScale
                self.baseScale = normalizeScale
                self.currentRotationY = 0
                applyTransform()

                anchorEntity.addChild(baseEntity)

                parent.stage = .placed

            } catch {
                parent.errorText = error.localizedDescription
                parent.stage = .failed
            }
        }

        @MainActor
        func convertToRealityKit(scnScene: SCNScene) async throws -> ModelEntity {
            let tempDir = FileManager.default.temporaryDirectory
            let tempUSDZ = tempDir.appendingPathComponent("converted_\(UUID().uuidString).usdz")

            let exported = scnScene.write(
                to: tempUSDZ,
                options: nil,
                delegate: nil,
                progressHandler: nil
            )

            guard exported else {
                throw ConversionError.exportFailed
            }

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
