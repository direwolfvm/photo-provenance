import CoreGraphics
import CryptoKit
import ImageIO
import UniformTypeIdentifiers

public struct PixelHash: Sendable {
    public let base64: String
    public let width: Int
    public let height: Int
}

public enum PixelCanonicalizerError: Error {
    case unsupportedImage
    case renderFailed
}

public enum PixelCanonicalizer {
    public static func canonicalPixelHash(imageData: Data) throws -> PixelHash {
        guard let source = CGImageSourceCreateWithData(imageData as CFData, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw PixelCanonicalizerError.unsupportedImage
        }

        let orientedImage = applyOrientation(source: source, image: cgImage)

        let width = orientedImage.width
        let height = orientedImage.height
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let bitsPerComponent = 8
        var pixels = [UInt8](repeating: 0, count: width * height * bytesPerPixel)

        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw PixelCanonicalizerError.renderFailed
        }

        context.draw(orientedImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        let digest = SHA256.hash(data: Data(pixels))
        let base64 = Data(digest).base64EncodedString()
        return PixelHash(base64: base64, width: width, height: height)
    }

    private static func applyOrientation(source: CGImageSource, image: CGImage) -> CGImage {
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        let orientationValue = properties?[kCGImagePropertyOrientation] as? UInt32 ?? 1
        let orientation = CGImagePropertyOrientation(rawValue: orientationValue) ?? .up
        return image.withOrientation(orientation) ?? image
    }
}

private extension CGImage {
    func withOrientation(_ orientation: CGImagePropertyOrientation) -> CGImage? {
        if orientation == .up {
            return self
        }
        let width = self.width
        let height = self.height
        let colorSpace = self.colorSpace ?? CGColorSpaceCreateDeviceRGB()

        var transform = CGAffineTransform.identity
        switch orientation {
        case .up:
            transform = .identity
        case .upMirrored:
            transform = CGAffineTransform(translationX: CGFloat(width), y: 0).scaledBy(x: -1, y: 1)
        case .down:
            transform = CGAffineTransform(translationX: CGFloat(width), y: CGFloat(height)).rotated(by: .pi)
        case .downMirrored:
            transform = CGAffineTransform(translationX: 0, y: CGFloat(height)).scaledBy(x: 1, y: -1)
        case .left:
            transform = CGAffineTransform(translationX: 0, y: CGFloat(width)).rotated(by: -.pi / 2)
        case .leftMirrored:
            transform = CGAffineTransform(translationX: CGFloat(height), y: CGFloat(width))
                .scaledBy(x: -1, y: 1)
                .rotated(by: -.pi / 2)
        case .right:
            transform = CGAffineTransform(translationX: CGFloat(height), y: 0).rotated(by: .pi / 2)
        case .rightMirrored:
            transform = CGAffineTransform(scaleX: -1, y: 1).rotated(by: .pi / 2)
        @unknown default:
            transform = .identity
        }

        let contextWidth = (orientation.isLandscape ? height : width)
        let contextHeight = (orientation.isLandscape ? width : height)
        guard let context = CGContext(
            data: nil,
            width: contextWidth,
            height: contextHeight,
            bitsPerComponent: self.bitsPerComponent,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: self.bitmapInfo.rawValue
        ) else {
            return nil
        }

        context.concatenate(transform)
        let drawRect = CGRect(x: 0, y: 0, width: width, height: height)
        context.draw(self, in: drawRect)
        return context.makeImage()
    }
}

private extension CGImagePropertyOrientation {
    var isLandscape: Bool {
        switch self {
        case .left, .leftMirrored, .right, .rightMirrored:
            return true
        default:
            return false
        }
    }
}
