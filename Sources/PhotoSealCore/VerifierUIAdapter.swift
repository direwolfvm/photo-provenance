import Foundation

#if canImport(C2PA)
import C2PA
#endif

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
        #if canImport(C2PA)
        let result = try C2PAVerifier.verify(assetData: assetData, sidecarData: sidecarData)
        let signatureValid = result.signatureStatus == .valid
        let contentBindingValid = result.bindingStatus == .valid
        let timestampPresent = result.timestampStatus == .present
        return VerificationSummary(
            signatureValid: signatureValid,
            contentBindingValid: contentBindingValid,
            timestampPresent: timestampPresent,
            activeManifestLabel: result.activeManifestLabel,
            rawJSON: result.json
        )
        #else
        throw VerifierUIAdapterError.sdkUnavailable
        #endif
    }
}
