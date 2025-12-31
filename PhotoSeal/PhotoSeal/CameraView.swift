import AVFoundation
import Combine
import CoreLocation
import Photos
import PhotoSealCore
import SwiftUI

struct CameraView: View {
    @StateObject private var viewModel = CameraViewModel()

    var body: some View {
        VStack(spacing: 20) {
            Text("PhotoSeal")
                .font(.largeTitle)

            CameraPreview(session: viewModel.captureSession)
                .frame(maxWidth: .infinity)
                .frame(height: 320)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(.secondary.opacity(0.2))
                )

            Toggle("Include Location", isOn: $viewModel.includeLocation)
            Toggle("Notarize when online", isOn: $viewModel.notarizeWhenOnline)

            Button(action: {
                Task { await viewModel.capturePhoto() }
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

    private let cameraCapture = CameraCapture()
    private let embedder = PhotoSealManifestEmbedder()

    var captureSession: AVCaptureSession {
        cameraCapture.captureSession
    }

    func start() {
        do {
            try cameraCapture.configure(enableLocation: includeLocation)
            cameraCapture.start()
        } catch {
            statusMessage = "Camera configuration failed: \(error.localizedDescription)"
        }
    }

    func stop() {
        cameraCapture.stop()
    }

    func capturePhoto() async {
        isCapturing = true
        defer { isCapturing = false }

        do {
            let result = try await cameraCapture.capturePhoto()
            let pixelHash = try PixelCanonicalizer.canonicalPixelHash(imageData: result.photoData)
            let assertion = CaptureAssertionPayload(metadata: result.metadata, pixelHash: pixelHash)
            if let schemaURL = Bundle.main.url(forResource: "org.photoseal.capture.v1.schema", withExtension: "json") {
                try? CaptureAssertionValidator.validate(payload: assertion, schemaURL: schemaURL)
            }

            let manifest = try PhotoSealManifestBuilder.buildManifest(
                creatorName: "Local User",
                capturePayload: assertion,
                notarizationRequested: notarizeWhenOnline,
                timestampURL: notarizeWhenOnline ? URL(string: "https://timestamp.contentauthenticity.org") : nil
            )
            let embedResult = try embedder.embedManifest(assetData: result.photoData, manifest: manifest)

            statusMessage = "Captured photo with custom manifest (\(embedResult.manifestStore.count) bytes)."
        } catch {
            statusMessage = "Capture failed: \(error.localizedDescription)"
        }
    }
}

private struct CameraPreview: View {
    let session: AVCaptureSession

    var body: some View {
        CameraPreviewLayerView(session: session)
            .aspectRatio(3 / 4, contentMode: .fill)
    }
}

#if os(iOS)
private struct CameraPreviewLayerView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        uiView.videoPreviewLayer.session = session
    }

    final class PreviewView: UIView {
        override class var layerClass: AnyClass {
            AVCaptureVideoPreviewLayer.self
        }

        var videoPreviewLayer: AVCaptureVideoPreviewLayer {
            guard let previewLayer = layer as? AVCaptureVideoPreviewLayer else {
                return AVCaptureVideoPreviewLayer()
            }
            return previewLayer
        }
    }
}
#elseif os(macOS)
private struct CameraPreviewLayerView: NSViewRepresentable {
    let session: AVCaptureSession

    func makeNSView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateNSView(_ nsView: PreviewView, context: Context) {
        nsView.videoPreviewLayer.session = session
    }

    final class PreviewView: NSView {
        override init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            wantsLayer = true
            layer = AVCaptureVideoPreviewLayer()
        }

        required init?(coder: NSCoder) {
            super.init(coder: coder)
            wantsLayer = true
            layer = AVCaptureVideoPreviewLayer()
        }

        var videoPreviewLayer: AVCaptureVideoPreviewLayer {
            guard let previewLayer = layer as? AVCaptureVideoPreviewLayer else {
                return AVCaptureVideoPreviewLayer()
            }
            return previewLayer
        }
    }
}
#endif
