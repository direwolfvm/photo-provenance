import Foundation

#if canImport(C2PA)
import C2PA
import ImageIO
import UniformTypeIdentifiers
#endif

public struct SigningOptions: Sendable {
    public let useTimestamp: Bool
    public let timestampURL: URL?

    public init(useTimestamp: Bool, timestampURL: URL?) {
        self.useTimestamp = useTimestamp
        self.timestampURL = timestampURL
    }
}

public struct EmbedResult: Sendable {
    public let assetData: Data
    public let manifestStore: Data
}

public enum C2PAEmbedderError: Error {
    case sdkUnavailable
    case signingMaterialUnavailable
    case embeddingFailed
}

public protocol C2PAEmbedding {
    func embedManifest(
        assetData: Data,
        manifestDefinition: ManifestDefinition,
        signingOptions: SigningOptions
    ) throws -> EmbedResult
}

public final class C2PAEmbedder: C2PAEmbedding {
    public init() {}

    public func embedManifest(
        assetData: Data,
        manifestDefinition: ManifestDefinition,
        signingOptions: SigningOptions
    ) throws -> EmbedResult {
        #if canImport(C2PA)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let definitionData = try encoder.encode(manifestDefinition)
        guard let manifestJSON = String(data: definitionData, encoding: .utf8) else {
            throw C2PAEmbedderError.embeddingFailed
        }

        let signer = try C2PASigningFactory.defaultSigner(
            useTimestamp: signingOptions.useTimestamp,
            timestampURL: signingOptions.timestampURL
        )
        let builder = try Builder(manifestJSON: manifestJSON)
        let sourceStream = try Stream(data: assetData)
        let destinationStream = try InMemoryWriteStream()
        let format = try C2PAFormatResolver.format(for: assetData)
        let manifestStore = try builder.sign(
            format: format,
            source: sourceStream,
            destination: destinationStream.stream,
            signer: signer
        )
        return EmbedResult(assetData: destinationStream.data, manifestStore: manifestStore)
        #else
        throw C2PAEmbedderError.sdkUnavailable
        #endif
    }
}

#if canImport(C2PA)
private enum C2PASigningFactory {
    static func defaultSigner(useTimestamp: Bool, timestampURL: URL?) throws -> Signer {
        guard
            let certURL = Bundle.module.url(forResource: "default_certs", withExtension: "pem"),
            let keyURL = Bundle.module.url(forResource: "default_private", withExtension: "key")
        else {
            throw C2PAEmbedderError.signingMaterialUnavailable
        }

        let certificates = try String(contentsOf: certURL)
        let privateKey = try String(contentsOf: keyURL)
        let tsaURL = useTimestamp ? timestampURL?.absoluteString : nil

        return try Signer(
            certsPEM: certificates,
            privateKeyPEM: privateKey,
            algorithm: .es256,
            tsaURL: tsaURL
        )
    }
}

private enum C2PAFormatResolver {
    static func format(for assetData: Data) throws -> String {
        guard
            let source = CGImageSourceCreateWithData(assetData as CFData, nil),
            let type = CGImageSourceGetType(source)
        else {
            throw C2PAEmbedderError.embeddingFailed
        }

        let identifier = type as String
        if let mime = UTType(identifier)?.preferredMIMEType {
            return mime
        }

        throw C2PAEmbedderError.embeddingFailed
    }
}

private final class InMemoryWriteStream {
    private(set) var data = Data()
    private var position = 0
    let stream: Stream

    init() throws {
        let seek: Stream.Seeker = { [weak self] offset, origin in
            guard let self else { return -1 }
            switch origin {
            case .Start:
                position = max(0, offset)
            case .Current:
                position = max(0, position + offset)
            case .End:
                position = max(0, data.count + offset)
            default:
                return -1
            }
            return position
        }
        let write: Stream.Writer = { [weak self] buffer, count in
            guard let self else { return -1 }
            let bytes = Data(bytes: buffer, count: count)
            if position == data.count {
                data.append(bytes)
            } else {
                if position + count > data.count {
                    data.append(Data(count: position + count - data.count))
                }
                data.replaceSubrange(position..<(position + count), with: bytes)
            }
            position += count
            return count
        }
        let flush: Stream.Flusher = { 0 }
        stream = try Stream(seek: seek, write: write, flush: flush)
    }
}
#endif
