import AVFoundation
import CoreLocation
import ImageIO

public struct PhotoCaptureMetadata: Sendable {
    public let exposureTime: Double?
    public let fNumber: Double?
    public let iso: Double?
    public let lensPosition: Float?
    public let deviceTime: Date
    public let location: CLLocation?
}

public struct PhotoCaptureResult: Sendable {
    public let photoData: Data
    public let metadata: PhotoCaptureMetadata
}

public enum CameraCaptureError: Error {
    case configurationFailed
    case captureFailed
}

public final class CameraCapture: NSObject {
    private let session = AVCaptureSession()
    private let output = AVCapturePhotoOutput()
    private let queue = DispatchQueue(label: "org.photoseal.capture")

    private var continuation: CheckedContinuation<PhotoCaptureResult, Error>?
    private var locationProvider: CLLocationManager?
    private var currentLocation: CLLocation?

    public override init() {
        super.init()
    }

    public func configure(enableLocation: Bool) throws {
        session.beginConfiguration()
        session.sessionPreset = .photo

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            session.commitConfiguration()
            throw CameraCaptureError.configurationFailed
        }

        let input = try AVCaptureDeviceInput(device: device)
        guard session.canAddInput(input) else {
            session.commitConfiguration()
            throw CameraCaptureError.configurationFailed
        }
        session.addInput(input)

        guard session.canAddOutput(output) else {
            session.commitConfiguration()
            throw CameraCaptureError.configurationFailed
        }
        session.addOutput(output)
        output.isHighResolutionCaptureEnabled = true
        session.commitConfiguration()

        if enableLocation {
            let manager = CLLocationManager()
            manager.requestWhenInUseAuthorization()
            manager.startUpdatingLocation()
            locationProvider = manager
        }
    }

    public func start() {
        queue.async {
            if !self.session.isRunning {
                self.session.startRunning()
            }
        }
    }

    public func stop() {
        queue.async {
            if self.session.isRunning {
                self.session.stopRunning()
            }
        }
    }

    public func capturePhoto() async throws -> PhotoCaptureResult {
        let settings = AVCapturePhotoSettings()
        settings.isHighResolutionPhotoEnabled = true
        settings.isAutoStillImageStabilizationEnabled = true
        if self.output.availablePhotoCodecTypes.contains(.hevc) {
            settings.codec = .hevc
        }

        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            self.currentLocation = locationProvider?.location
            output.capturePhoto(with: settings, delegate: self)
        }
    }
}

extension CameraCapture: AVCapturePhotoCaptureDelegate {
    public func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            continuation?.resume(throwing: error)
            continuation = nil
            return
        }

        guard let data = photo.fileDataRepresentation() else {
            continuation?.resume(throwing: CameraCaptureError.captureFailed)
            continuation = nil
            return
        }

        let metadataDictionary = photo.metadata
        let exif = metadataDictionary[kCGImagePropertyExifDictionary as String] as? [String: Any]
        let exposureTime = exif?[kCGImagePropertyExifExposureTime as String] as? Double
        let fNumber = exif?[kCGImagePropertyExifFNumber as String] as? Double
        let iso = exif?[kCGImagePropertyExifISOSpeedRatings as String] as? [Double]
        let lensPosition = metadataDictionary[kCGImagePropertyExifLensSpecification as String] as? Float

        let metadata = PhotoCaptureMetadata(
            exposureTime: exposureTime,
            fNumber: fNumber,
            iso: iso?.first,
            lensPosition: lensPosition,
            deviceTime: Date(),
            location: currentLocation
        )

        continuation?.resume(returning: PhotoCaptureResult(photoData: data, metadata: metadata))
        continuation = nil
    }
}
