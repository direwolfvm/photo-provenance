import Foundation

#if canImport(C2PA)
import C2PA
#endif

public struct SigningOptions: Sendable {
    public let useTimestamp: Bool
    public let timestampURL: URL?
}

public struct EmbedResult: Sendable {
    public let assetData: Data
    public let manifestStore: Data
}

public enum C2PAEmbedderError: Error {
    case sdkUnavailable
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

        let signer = try C2PASigningFactory.defaultSigner(useTimestamp: signingOptions.useTimestamp, timestampURL: signingOptions.timestampURL)
        let manifestStore = try C2PASDK.embedManifestStore(
            assetData: assetData,
            manifestDefinitionJSON: definitionData,
            signer: signer
        )
        return EmbedResult(assetData: manifestStore.asset, manifestStore: manifestStore.store)
        #else
        throw C2PAEmbedderError.sdkUnavailable
        #endif
    }
}

#if canImport(C2PA)
private enum C2PASigningFactory {
    static func defaultSigner(useTimestamp: Bool, timestampURL: URL?) throws -> C2PASigner {
        var options = C2PASignerOptions()
        if useTimestamp, let timestampURL {
            options.timestampURL = timestampURL
        }
        return try C2PASigner(options: options)
    }
}
#endif
