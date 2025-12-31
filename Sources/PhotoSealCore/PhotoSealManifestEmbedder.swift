import Foundation

public struct EmbedResult: Sendable {
    public let assetData: Data
    public let manifestStore: Data
}

public enum ManifestEmbedderError: Error {
    case encodingFailed
}

public protocol ManifestEmbedding {
    func embedManifest(
        assetData: Data,
        manifest: PhotoSealManifest
    ) throws -> EmbedResult
}

public final class PhotoSealManifestEmbedder: ManifestEmbedding {
    public init() {}

    public func embedManifest(
        assetData: Data,
        manifest: PhotoSealManifest
    ) throws -> EmbedResult {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let definitionData = try encoder.encode(manifest)
        return EmbedResult(assetData: assetData, manifestStore: definitionData)
    }
}
