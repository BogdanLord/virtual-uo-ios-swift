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

            overlayUI
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

    private var overlayUI: some View {
        VStack {
            topBar
            Spacer()
            bottomStatus
        }
    }

    private var topBar: some View {
        HStack {
            closeButton
            Spacer()
            titleBadge
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    private var closeButton: some View {
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
    }

    private var titleBadge: some View {
        Text(experience.title)
            .font(.system(size: 14, weight: .bold))
            .foregroundColor(.white)
            .lineLimit(1)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
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
        case .placed: return "Pinch pentru zoom, roteste cu 2 degete"
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

        let tap = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleTap(_:))
        )
        arView.addGestureRecognizer(tap)

        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, ARSessionDelegate {
        var parent: ARViewContainer
        weak var arView: ARView?
        var hasFoundPlane = false
        var modelPlaced = false
        var modelEntity: ModelEntity?

        init(_ parent: ARViewContainer) {
            self.parent = parent
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

                let modelEntity = try await convertToRealityKit(scnScene: scnScene)

                let bounds = modelEntity.visualBounds(relativeTo: nil)
                let center = bounds.center
                modelEntity.position = SIMD3<Float>(
                    -center.x,
                    -bounds.min.y,
                    -center.z
                )

                let maxDim = max(bounds.extents.x, max(bounds.extents.y, bounds.extents.z))
                if maxDim > 0 {
                    let scale = Float(0.3) / maxDim
                    modelEntity.scale = SIMD3<Float>(repeating: scale)
                }

                let wrapper = ModelEntity()
                wrapper.addChild(modelEntity)
                wrapper.generateCollisionShapes(recursive: true)

                anchorEntity.addChild(wrapper)
                self.modelEntity = wrapper

                if let arView = arView {
                    arView.installGestures([.scale, .rotation], for: wrapper)
                }

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
