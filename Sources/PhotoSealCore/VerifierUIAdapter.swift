import Foundation

public struct VerificationSummary: Sendable {
    public let signatureValid: Bool
    public let contentBindingValid: Bool
    public let timestampPresent: Bool
    public let activeManifestLabel: String?
    public let rawJSON: String
}

public enum VerifierUIAdapterError: Error {
    case sdkUnavailable
    case verificationFailed
}

public protocol VerificationProviding {
    func verify(assetData: Data, sidecarData: Data?) throws -> VerificationSummary
}

public final class VerifierUIAdapter: VerificationProviding {
    public init() {}

    public func verify(assetData: Data, sidecarData: Data?) throws -> VerificationSummary {
        guard let sidecarData else {
            throw VerifierUIAdapterError.verificationFailed
        }

        let decoder = JSONDecoder()
        let manifest = try decoder.decode(PhotoSealManifest.self, from: sidecarData)
        let assetHash = try PixelCanonicalizer.canonicalPixelHash(imageData: assetData)
        let contentBindingValid = assetHash.base64 == manifest.assetBinding.hashValue
            && assetHash.width == manifest.assetBinding.width
            && assetHash.height == manifest.assetBinding.height
        let timestampPresent = manifest.notarization?.requested ?? false
        guard let rawJSON = String(data: sidecarData, encoding: .utf8) else {
            throw VerifierUIAdapterError.verificationFailed
        }

        return VerificationSummary(
            signatureValid: false,
            contentBindingValid: contentBindingValid,
            timestampPresent: timestampPresent,
            activeManifestLabel: manifest.manifestVersion,
            rawJSON: rawJSON
        )
    }
}
