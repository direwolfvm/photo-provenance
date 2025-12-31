import Foundation

public struct ManifestDefinition: Codable, Sendable {
    public struct Assertion: Codable, Sendable {
        public let label: String
        public let data: [String: AnyCodable]
        public let kind: String?
    }

    public let claimGenerator: String
    public let claimGeneratorInfo: [String: String]
    public let assertions: [Assertion]

    enum CodingKeys: String, CodingKey {
        case claimGenerator = "claim_generator"
        case claimGeneratorInfo = "claim_generator_info"
        case assertions
    }
}

public enum C2PAManifestBuilder {
    public static func buildManifestDefinition(
        creatorName: String,
        capturePayload: CaptureAssertionPayload
    ) throws -> ManifestDefinition {
        let createdAction: [String: AnyCodable] = [
            "actions": .array([
                .dictionary([
                    "action": .string("c2pa.created"),
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

        return ManifestDefinition(
            claimGenerator: "PhotoSeal iOS",
            claimGeneratorInfo: [
                "name": "PhotoSeal",
                "version": "0.1",
                "icon": "app://photoseal"
            ],
            assertions: [
                ManifestDefinition.Assertion(
                    label: "c2pa.actions",
                    data: createdAction,
                    kind: "c2pa.actions"
                ),
                ManifestDefinition.Assertion(
                    label: "stds.schema-org.CreativeWork",
                    data: creativeWork,
                    kind: "stds.schema-org.CreativeWork"
                ),
                ManifestDefinition.Assertion(
                    label: "org.photoseal.capture.v1",
                    data: captureData,
                    kind: "org.photoseal.capture.v1"
                )
            ]
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
