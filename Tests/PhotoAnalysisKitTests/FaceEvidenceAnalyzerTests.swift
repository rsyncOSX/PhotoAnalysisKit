import CoreGraphics
import Foundation
import Testing
@testable import PhotoAnalysisKit

struct FaceEvidenceAnalyzerTests {
    @Test func convertsAndClipsVisionCoordinates() {
        #expect(FaceEvidenceAnalyzer.topLeftBounds(
            fromVision: CGRect(x: -0.125, y: 0.625, width: 0.5, height: 0.25)
        ) == CGRect(x: 0, y: 0.125, width: 0.375, height: 0.25))
        #expect(FaceEvidenceAnalyzer.topLeftBounds(
            fromVision: CGRect(x: 2, y: 2, width: 0.25, height: 0.25)
        ) == nil)
    }

    @Test func detailUsesTheRequestedFaceRegion() throws {
        let width = 160
        let height = 80
        let pixels: [UInt8] = (0..<(width * height)).map { index in
            let x = index % width
            return x < width / 2 ? 128 : (x / 4).isMultiple(of: 2) ? 32 : 224
        }
        let provider = try #require(CGDataProvider(data: Data(pixels) as CFData))
        let image = try #require(CGImage(
            width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 8,
            bytesPerRow: width, space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
            provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent
        ))

        let flat = try #require(FaceEvidenceAnalyzer.measureDetail(
            in: image, bounds: CGRect(x: 0, y: 0, width: 0.5, height: 1)
        ))
        let textured = try #require(FaceEvidenceAnalyzer.measureDetail(
            in: image, bounds: CGRect(x: 0.5, y: 0, width: 0.5, height: 1)
        ))
        #expect(flat == 0)
        #expect(textured > flat)
        #expect(FaceEvidenceAnalyzer.measureDetail(
            in: image, bounds: CGRect(x: 0, y: 0, width: 0.1, height: 0.1)
        ) == nil)
    }
}
