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

    enum ARStage {
        case scanning, readyToPlace, downloading, placed, failed
    }

    var body: some View {
        ZStack {
            ARViewContainer(
                experience: experience,
                stage: $stage,
                statusDetail: $statusDetail,
                errorText: $errorText,
                selectedAnnotation: $selectedAnnotation
            )
            .ignoresSafeArea()

            VStack {
                topBar
                Spacer()
                if selectedAnnotation == nil {
                    bottomStatus
                }
            }

            if let ann = selectedAnnotation {
                annotationPanel(ann)
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
            TTSService.shared.stop()
        }
    }

    private var topBar: some View {
        HStack {
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
        case .placed: return "Atinge punctele verzi pentru detalii"
        case .failed: return "A aparut o problema"
        }
    }

    // Panou adnotare jos
    private func annotationPanel(_ ann: Annotation) -> some View {
        VStack {
            Spacer()
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(ann.title)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(Color(red: 0.0, green: 1.0, blue: 0.53))
                    Spacer()
                    Button {
                        TTSService.shared.stop()
                        selectedAnnotation = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 26))
                            .foregroundColor(.gray)
                    }
                }

                if let text = ann.text, !text.isEmpty {
                    ScrollView {
                        Text(text)
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.9))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 120)

                    Button {
                        TTSService.shared.speak(text)
                    } label: {
                        HStack {
                            Image(systemName: "speaker.wave.2.fill")
                            Text("Asculta Audio")
                        }
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Color(red: 0.18, green: 0.83, blue: 0.75))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color(red: 0.18, green: 0.83, blue: 0.75).opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
            .padding(18)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
    }
}

struct ARViewContainer: UIViewRepresentable {
    let experience: Experience
    @Binding var stage: ARExperienceView.ARStage
    @Binding var statusDetail: String
    @Binding var errorText: String?
    @Binding var selectedAnnotation: Annotation?

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

        // Maparea entitate-sfera → adnotare
        var annotationEntities: [ObjectIdentifier: Annotation] = [:]

        init(_ parent: ARViewContainer) {
            self.parent = parent
        }

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

        // TAP - plaseaza model SAU selecteaza adnotare
        @objc func handleTap(_ sender: UITapGestureRecognizer) {
            guard let arView = arView else { return }
            let tapLocation = sender.location(in: arView)

            // Daca modelul e plasat, verificam daca am atins o adnotare
            if modelPlaced {
                if let hitEntity = arView.entity(at: tapLocation) {
                    // Cautam in ierarhie o adnotare
                    var entity: Entity? = hitEntity
                    while let e = entity {
                        if let ann = annotationEntities[ObjectIdentifier(e)] {
                            DispatchQueue.main.async {
                                self.parent.selectedAnnotation = ann
                            }
                            return
                        }
                        entity = e.parent
                    }
                }
                return
            }

            // Altfel, plasam modelul
            guard parent.stage == .readyToPlace else { return }

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

        @objc func handlePinch(_ sender: UIPinchGestureRecognizer) {
            guard transformEntity != nil else { return }
            if sender.state == .began { baseScale = currentScale }
            if sender.state == .changed || sender.state == .ended {
                let newScale = baseScale * Float(sender.scale)
                currentScale = min(max(newScale, 0.2), 5.0)
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
            guard let entity = transformEntity else { return }
            entity.transform.scale = SIMD3<Float>(repeating: currentScale)
            entity.transform.rotation = simd_quatf(
                angle: currentRotationY,
                axis: SIMD3<Float>(0, 1, 0)
            )
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

                let bounds = rawModel.visualBounds(relativeTo: nil)
                let center = bounds.center
                let maxDim = max(bounds.extents.x, max(bounds.extents.y, bounds.extents.z))
                let normalizeScale = maxDim > 0 ? (Float(0.3) / maxDim) : 1.0

                let innerEntity = Entity()
                rawModel.position = SIMD3<Float>(-center.x, -center.y, -center.z)
                innerEntity.addChild(rawModel)

                let transformEntity = Entity()
                transformEntity.addChild(innerEntity)

                // ── ADNOTARI 3D ──
                // Adaugam sfere verzi in transformEntity (se scaleaza/rotesc cu modelul)
                addAnnotations(to: transformEntity, modelBounds: bounds)

                let modelHeight = bounds.extents.y * normalizeScale
                let baseEntity = Entity()
                baseEntity.position = SIMD3<Float>(0, modelHeight / 2.0, 0)
                baseEntity.addChild(transformEntity)

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

        // Creeaza sferele de adnotare
        func addAnnotations(to parentEntity: Entity, modelBounds: BoundingBox) {
            guard let annotations = parent.experience.annotations else { return }

            for ann in annotations {
                // Pozitia 3D din baza de date
                let pos = ann.position3D

                // Sfera verde
                let sphere = MeshResource.generateSphere(radius: 0.04)
                var material = UnlitMaterial()
                material.color = .init(tint: UIColor(
                    red: 0, green: 1, blue: 0.53, alpha: 1
                ))
                let sphereEntity = ModelEntity(mesh: sphere, materials: [material])
                sphereEntity.position = pos

                // Collision ca sa fie detectabila la tap
                sphereEntity.generateCollisionShapes(recursive: false)

                // Halo (sfera mai mare semitransparenta)
                let halo = MeshResource.generateSphere(radius: 0.06)
                var haloMat = UnlitMaterial()
                haloMat.color = .init(tint: UIColor(
                    red: 0, green: 1, blue: 0.53, alpha: 0.25
                ))
                let haloEntity = ModelEntity(mesh: halo, materials: [haloMat])
                sphereEntity.addChild(haloEntity)

                parentEntity.addChild(sphereEntity)

                // Mapam entitatea la adnotare
                annotationEntities[ObjectIdentifier(sphereEntity)] = ann
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
