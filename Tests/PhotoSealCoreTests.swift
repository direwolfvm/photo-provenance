import XCTest

final class PhotoSealCoreTests: XCTestCase {
    func testPixelHashProducesBase64() throws {
        let bundle = Bundle(for: Self.self)
        guard let url = bundle.url(forResource: "sample", withExtension: "jpg") else {
            return
        }
        let data = try Data(contentsOf: url)
        let hash = try PixelCanonicalizer.canonicalPixelHash(imageData: data)
        XCTAssertFalse(hash.base64.isEmpty)
        XCTAssertGreaterThan(hash.width, 0)
        XCTAssertGreaterThan(hash.height, 0)
    }
}
