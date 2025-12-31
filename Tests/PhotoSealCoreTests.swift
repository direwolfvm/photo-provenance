import Foundation
import PhotoSealCore
import XCTest

final class PhotoSealCoreTests: XCTestCase {
    func testPixelHashProducesBase64() throws {
        let base64PNG =
            "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMB/6X3SbkAAAAASUVORK5CYII="
        guard let data = Data(base64Encoded: base64PNG) else {
            XCTFail("Failed to decode base64 PNG test image.")
            return
        }

        let hash = try PixelCanonicalizer.canonicalPixelHash(imageData: data)
        XCTAssertFalse(hash.base64.isEmpty)
        XCTAssertGreaterThan(hash.width, 0)
        XCTAssertGreaterThan(hash.height, 0)
    }
}
