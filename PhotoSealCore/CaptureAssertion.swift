import Foundation
import CoreLocation

public struct CaptureAssertionPayload: Codable, Sendable {
    public struct PixelHashInfo: Codable, Sendable {
        public let algorithm: String
        public let value: String
        public let width: Int
        public let height: Int
    }

    public let deviceTime: String
    public let exposureTime: Double?
    public let fNumber: Double?
    public let iso: Double?
    public let lensPosition: Float?
    public let location: LocationInfo?
    public let pixelHash: PixelHashInfo

    public struct LocationInfo: Codable, Sendable {
        public let latitude: Double
        public let longitude: Double
        public let altitude: Double?
        public let horizontalAccuracy: Double?
    }

    public init(metadata: PhotoCaptureMetadata, pixelHash: PixelHash) {
        let formatter = ISO8601DateFormatter()
        self.deviceTime = formatter.string(from: metadata.deviceTime)
        self.exposureTime = metadata.exposureTime
        self.fNumber = metadata.fNumber
        self.iso = metadata.iso
        self.lensPosition = metadata.lensPosition
        if let location = metadata.location {
            self.location = LocationInfo(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                altitude: location.altitude,
                horizontalAccuracy: location.horizontalAccuracy
            )
        } else {
            self.location = nil
        }
        self.pixelHash = PixelHashInfo(
            algorithm: "SHA-256",
            value: pixelHash.base64,
            width: pixelHash.width,
            height: pixelHash.height
        )
    }
}

public enum CaptureAssertionValidator {
    public static func validate(payload: CaptureAssertionPayload, schemaURL: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(payload)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let schemaData = try Data(contentsOf: schemaURL)
        let schema = try JSONSerialization.jsonObject(with: schemaData) as? [String: Any]

        guard let schemaProperties = schema?["properties"] as? [String: Any] else {
            return
        }

        let requiredKeys = schema?["required"] as? [String] ?? []
        let payloadKeys = Set(json?.keys ?? [])
        let missing = requiredKeys.filter { !payloadKeys.contains($0) }
        if !missing.isEmpty {
            throw NSError(domain: "org.photoseal.validation", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Missing required keys: \(missing.joined(separator: ", "))"
            ])
        }

        for key in payloadKeys {
            if schemaProperties[key] == nil {
                throw NSError(domain: "org.photoseal.validation", code: 2, userInfo: [
                    NSLocalizedDescriptionKey: "Unexpected key: \(key)"
                ])
            }
        }
    }
}
