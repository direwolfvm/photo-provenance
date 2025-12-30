import SwiftUI
import CoreLocation
import Photos

struct CameraView: View {
    @StateObject private var viewModel = CameraViewModel()

    var body: some View {
        VStack(spacing: 20) {
            Text("PhotoSeal")
                .font(.largeTitle)

            Toggle("Include Location", isOn: $viewModel.includeLocation)
            Toggle("Notarize when online", isOn: $viewModel.notarizeWhenOnline)

            Button(action: {
                Task { await viewModel.capture() }
            }) {
                Text(viewModel.isCapturing ? "Capturing..." : "Capture")
            }
            .disabled(viewModel.isCapturing)

            if let status = viewModel.statusMessage {
                Text(status)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .onAppear { viewModel.start() }
        .onDisappear { viewModel.stop() }
    }
}

@MainActor
final class CameraViewModel: ObservableObject {
    @Published var includeLocation = false
    @Published var notarizeWhenOnline = true
    @Published var isCapturing = false
    @Published var statusMessage: String?

    private let capture = CameraCapture()
    private let embedder = C2PAEmbedder()

    func start() {
        do {
            try capture.configure(enableLocation: includeLocation)
            capture.start()
        } catch {
            statusMessage = "Camera configuration failed: \(error.localizedDescription)"
        }
    }

    func stop() {
        capture.stop()
    }

    func capture() async {
        isCapturing = true
        defer { isCapturing = false }

        do {
            let result = try await capture.capturePhoto()
            let pixelHash = try PixelCanonicalizer.canonicalPixelHash(imageData: result.photoData)
            let assertion = CaptureAssertionPayload(metadata: result.metadata, pixelHash: pixelHash)
            if let schemaURL = Bundle.main.url(forResource: "org.photoseal.capture.v1.schema", withExtension: "json") {
                try? CaptureAssertionValidator.validate(payload: assertion, schemaURL: schemaURL)
            }

            let manifest = try C2PAManifestBuilder.buildManifestDefinition(
                creatorName: "Local User",
                capturePayload: assertion
            )
            let signingOptions = SigningOptions(
                useTimestamp: notarizeWhenOnline,
                timestampURL: notarizeWhenOnline ? URL(string: "https://timestamp.contentauthenticity.org") : nil
            )
            let embedResult = try embedder.embedManifest(
                assetData: result.photoData,
                manifestDefinition: manifest,
                signingOptions: signingOptions
            )

            statusMessage = "Captured photo with manifest store (\(embedResult.manifestStore.count) bytes)."
        } catch {
            statusMessage = "Capture failed: \(error.localizedDescription)"
        }
    }
}
