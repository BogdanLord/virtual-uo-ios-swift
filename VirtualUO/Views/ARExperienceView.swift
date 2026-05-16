import SwiftUI
import RealityKit
import ARKit

// MARK: - Ecran AR principal
struct ARExperienceView: View {
    let experience: Experience
    @Environment(\.dismiss) private var dismiss

    @State private var arStatus: String = "Initializare AR..."
    @State private var modelPlaced = false

    var body: some View {
        ZStack {
            // AR View nativ RealityKit
            ARViewContainer(
                experience: experience,
                arStatus: $arStatus,
                modelPlaced: $modelPlaced
            )
            .ignoresSafeArea()

            // UI peste AR
            VStack {
                // Bara de sus
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

                Spacer()

                // Status jos
                Text(arStatus)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .padding(.bottom, 30)
            }
        }
        .navigationBarHidden(true)
        .statusBarHidden(true)
    }
}

// MARK: - ARView Container (puntea intre SwiftUI si RealityKit)
struct ARViewContainer: UIViewRepresentable {
    let experience: Experience
    @Binding var arStatus: String
    @Binding var modelPlaced: Bool

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)

        // Configurare ARKit: world tracking + plane detection
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal, .vertical]
        config.environmentTexturing = .automatic

        // Activeaza people occlusion daca dispozitivul suporta
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.personSegmentationWithDepth) {
            config.frameSemantics.insert(.personSegmentationWithDepth)
        }

        arView.session.run(config)

        // Coordinator gestioneaza evenimentele
        context.coordinator.arView = arView
        arView.session.delegate = context.coordinator

        DispatchQueue.main.async {
            arStatus = "Misca telefonul ca sa scanezi podeaua"
        }

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

        init(_ parent: ARViewContainer) {
            self.parent = parent
        }

        func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
            // Cand ARKit detecteaza un plan
            for anchor in anchors {
                if anchor is ARPlaneAnchor {
                    DispatchQueue.main.async {
                        self.parent.arStatus = "Suprafata detectata! Atinge ecranul."
                    }
                }
            }
        }

        func session(_ session: ARSession, didFailWithError error: Error) {
            DispatchQueue.main.async {
                self.parent.arStatus = "Eroare AR: \(error.localizedDescription)"
            }
        }
    }
}
