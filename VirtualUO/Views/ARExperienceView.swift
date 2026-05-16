import SwiftUI
import RealityKit
import ARKit
import Combine

struct ARExperienceView: View {
    let experience: Experience
    @Environment(\.dismiss) private var dismiss

    @State private var arStatus = "Initializare AR..."
    @State private var stage: ARStage = .scanning
    @State private var downloadProgress = ""
    @State private var errorText: String?

    enum ARStage {
        case scanning, readyToPlace, placed, downloading, failed
    }

    var body: some View {
        ZStack {
            ARViewContainer(
                experience: experience,
                arStatus: $arStatus,
                stage: $stage,
                downloadProgress: $downloadProgress,
                errorText: $errorText
            )
            .ignoresSafeArea()

            overlayUI
        }
        .navigationBarHidden(true)
        .statusBarHidden(true)
        .onAppear {
            AppDelegate.orientationLock = .landscape
            UIDevice.current.setValue(UIInterfaceOrientation.landscapeRight.rawValue, forKey: "orientation")
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
        VStack(spacing: 8) {
            if let err = errorText {
                Text("Eroare: \(err)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
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
        case .downloading: return "Se descarca modelul... \(downloadProgress)"
        case .placed: return "Model plasat! Apropie-te si exploreaza"
        case .failed: return "A aparut o problema"
        }
    }
}

// MARK: - ARView Container
struct ARViewContainer: UIViewRepresentable {
    let experience: Experience
    @Binding var arStatus: String
    @Binding var stage: ARExperienceView.ARStage
    @Binding var downloadProgress: String
    @Binding var errorText: String?

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)

        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal]
        config.environmentTexturing = .automatic

        arView.session.run(config)
        arView.session.delegate = context.coordinator
        context.coordinator.arView = arView

        // Gesture pentru tap (plasare model)
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

    // MARK: - Coordinator
    class Coordinator: NSObject, ARSessionDelegate {
        var parent: ARViewContainer
        weak var arView: ARView?
        var hasFoundPlane = false
        var modelPlaced = false
        var modelEntity: ModelEntity?

        init(_ parent: ARViewContainer) {
            self.parent = parent
        }

        // Cand ARKit gaseste un plan orizontal
        func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
            for anchor in anchors {
                if anchor is ARPlaneAnchor, !hasFoundPlane {
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

        // TAP pe ecran → plasare model
        @objc func handleTap(_ sender: UITapGestureRecognizer) {
            guard let arView = arView else { return }
            guard !modelPlaced else { return }
            guard parent.stage == .readyToPlace else { return }

            let tapLocation = sender.location(in: arView)

            // Raycast: gasim unde lovim podeaua in lumea reala
            let results = arView.raycast(
                from: tapLocation,
                allowing: .estimatedPlane,
                alignment: .horizontal
            )

            guard let firstResult = results.first else {
                DispatchQueue.main.async {
                    self.parent.arStatus = "Indreapta camera spre podea"
                }
                return
            }

            modelPlaced = true

            // Cream anchor in punctul lovit
            let anchor = AnchorEntity(world: firstResult.worldTransform)
            arView.scene.addAnchor(anchor)

            DispatchQueue.main.async {
                self.parent.stage = .downloading
            }

            // Descarcam si plasam modelul
            Task {
                await self.loadAndPlaceModel(anchor: anchor)
            }
        }

        // Descarca USDZ si il pune in scena
        @MainActor
        func loadAndPlaceModel(anchor: AnchorEntity) async {
            guard let modelURLString = parent.experience.model_url_ios else {
                parent.errorText = "Nu exista model USDZ pentru aceasta experienta"
                parent.stage = .failed
                return
            }

            do {
                // Descarcam fisierul
                let localURL = try await ARModelDownloader.shared.downloadModel(from: modelURLString)

                parent.downloadProgress = "Se proceseaza..."

                // Incarcam modelul in RealityKit
                let entity = try await ModelEntity(contentsOf: localURL)

                // Scalam modelul sa aiba ~30cm
                let bounds = entity.visualBounds(relativeTo: nil)
                let size = bounds.extents
                let maxDim = max(size.x, max(size.y, size.z))
                let targetSize: Float = 0.3
                if maxDim > 0 {
                    let scale = targetSize / maxDim
                    entity.scale = SIMD3<Float>(repeating: scale)
                }

                // Activam interactiunile (mutare, rotire, scalare cu degetele)
                entity.generateCollisionShapes(recursive: true)

                anchor.addChild(entity)
                self.modelEntity = entity

                // Activam gesturile pe model
                if let arView = arView {
                    arView.installGestures([.rotation, .scale], for: entity)
                }

                parent.stage = .placed

            } catch {
                parent.errorText = error.localizedDescription
                parent.stage = .failed
            }
        }
    }
}
