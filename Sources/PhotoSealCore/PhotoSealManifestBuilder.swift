import Foundation

public struct PhotoSealManifest: Codable, Sendable {
    public struct Generator: Codable, Sendable {
        public let name: String
        public let version: String
        public let icon: String?
    }

    public struct AssetBinding: Codable, Sendable {
        public let hashAlgorithm: String
        public let hashValue: String
        public let width: Int
        public let height: Int
        public let source: String

        enum CodingKeys: String, CodingKey {
            case hashAlgorithm = "hash_algorithm"
            case hashValue = "hash_value"
            case width
            case height
            case source
        }
    }

    public struct Notarization: Codable, Sendable {
        public let requested: Bool
        public let timestampURL: String?

        enum CodingKeys: String, CodingKey {
            case requested
            case timestampURL = "timestamp_url"
        }
    }

    public struct Assertion: Codable, Sendable {
        public let label: String
        public let data: [String: AnyCodable]
        public let kind: String?
    }

    public let manifestVersion: String
    public let created: String
    public let generator: Generator
    public let assetBinding: AssetBinding
    public let assertions: [Assertion]
    public let notarization: Notarization?

    enum CodingKeys: String, CodingKey {
        case manifestVersion = "manifest_version"
        case created
        case generator
        case assetBinding = "asset_binding"
        case assertions
        case notarization
    }
}

public enum PhotoSealManifestBuilder {
    public static func buildManifest(
        creatorName: String,
        capturePayload: CaptureAssertionPayload,
        notarizationRequested: Bool,
        timestampURL: URL?
    ) throws -> PhotoSealManifest {
        let createdAction: [String: AnyCodable] = [
            "actions": .array([
                .dictionary([
                    "action": .string("photoseal.created"),
                    "when": .string(capturePayload.deviceTime)
                ])
            ])
        ]

        let creativeWork: [String: AnyCodable] = [
            "@context": .string("https://schema.org"),
            "@type": .string("CreativeWork"),
            "creator": .dictionary([
                "@type": .string("Person"),
                "name": .string(creatorName)
            ])
        ]

        let captureData = try payloadDictionary(from: capturePayload)

        let assetBinding = PhotoSealManifest.AssetBinding(
            hashAlgorithm: capturePayload.pixelHash.algorithm,
            hashValue: capturePayload.pixelHash.value,
            width: capturePayload.pixelHash.width,
            height: capturePayload.pixelHash.height,
            source: "pixel_hash_v1"
        )

        let notarization = PhotoSealManifest.Notarization(
            requested: notarizationRequested,
            timestampURL: timestampURL?.absoluteString
        )

        return PhotoSealManifest(
            manifestVersion: "photoseal.manifest.v1",
            created: capturePayload.deviceTime,
            generator: PhotoSealManifest.Generator(
                name: "PhotoSeal iOS",
                version: "0.1",
                icon: "app://photoseal"
            ),
            assetBinding: assetBinding,
            assertions: [
                PhotoSealManifest.Assertion(
                    label: "photoseal.actions",
                    data: createdAction,
                    kind: "photoseal.actions"
                ),
                PhotoSealManifest.Assertion(
                    label: "photoseal.schema-org.CreativeWork",
                    data: creativeWork,
                    kind: "schema-org.CreativeWork"
                ),
                PhotoSealManifest.Assertion(
                    label: "org.photoseal.capture.v1",
                    data: captureData,
                    kind: "org.photoseal.capture.v1"
                )
            ],
            notarization: notarization
        )
    }

    private static func payloadDictionary(from payload: CaptureAssertionPayload) throws -> [String: AnyCodable] {
        let data = try JSONEncoder().encode(payload)
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        return object?.mapValues { AnyCodable($0) } ?? [:]
    }
}

public struct AnyCodable: Codable, @unchecked Sendable {
    public let value: Any

    public init(_ value: Any) {
        self.value = value
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            value = string
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues { $0.value }
        } else {
            value = NSNull()
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case let string as String:
            try container.encode(string)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let bool as Bool:
            try container.encode(bool)
        case let array as [Any]:
            try container.encode(array.map(AnyCodable.init))
        case let dict as [String: Any]:
            try container.encode(dict.mapValues(AnyCodable.init))
        default:
            try container.encodeNil()
        }
    }

    public static func string(_ value: String) -> AnyCodable { AnyCodable(value) }
    public static func dictionary(_ value: [String: AnyCodable]) -> AnyCodable { AnyCodable(value) }
    public static func array(_ value: [AnyCodable]) -> AnyCodable { AnyCodable(value.map { $0.value }) }
}
