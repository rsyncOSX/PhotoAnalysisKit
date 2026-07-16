import CoreGraphics
import PhotoAnalysisKit
import Testing

@Suite("PhotoAnalyzer end-to-end")
struct PhotoAnalyzerTests {
    @Test("Sharpness analysis loads the package Metal kernel")
    func sharpnessAnalysis() async throws {
        let image = try #require(makeCheckerboardImage())
        let analyzer = PhotoAnalyzer()
        var configuration = SharpnessConfiguration.birdsInFlight
        configuration.enableSubjectClassification = false
        let input = PhotoAnalysisInput(
            image: image,
            iso: 800,
            aperture: 5.6,
            normalizedAFPoint: CGPoint(x: 0.5, y: 0.5)
        )

        let result = await analyzer.analyze(input, configuration: configuration)

        let breakdown = try #require(result.breakdown)
        #expect(breakdown.finalScore.isFinite)
        #expect(breakdown.finalScore >= 0)
        #expect(breakdown.globalScore != nil)
        #expect(result.focusMask == nil)
    }

    @Test("Focus-mask analysis returns an image and diagnostics")
    func focusMaskAnalysis() async throws {
        let image = try #require(makeCheckerboardImage())
        let analyzer = PhotoAnalyzer()
        var configuration = SharpnessConfiguration.birdsInFlight
        configuration.enableSubjectClassification = false
        configuration.isolateMaskToSubject = false

        let result = await analyzer.analyzeWithFocusMask(
            PhotoAnalysisInput(image: image, iso: 400),
            configuration: configuration
        )

        let mask = try #require(result.focusMask)
        #expect(mask.width > 0)
        #expect(mask.height > 0)
        #expect(result.breakdown?.focusMaskRegionSource != nil)
    }

    @Test("Calibration accepts decoded images and neutral metadata")
    func calibration() async throws {
        let image = try #require(makeCheckerboardImage())
        let inputs = (0 ..< 3).map { index in
            PhotoAnalysisInput(
                image: image,
                iso: 400 + index * 400,
                aperture: 4 + Double(index)
            )
        }

        let result = await PhotoAnalyzer().calibrate(
            from: inputs,
            minimumSuccessfulImages: 3,
            maximumConcurrentTasks: 2
        )

        let calibration = try #require(result)
        #expect(calibration.sampleCount > 0)
        #expect((0.01 ... 0.95).contains(calibration.threshold))
    }
}

func makeCheckerboardImage(size: Int = 128) -> CGImage? {
    guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
          let context = CGContext(
              data: nil,
              width: size,
              height: size,
              bitsPerComponent: 8,
              bytesPerRow: size * 4,
              space: colorSpace,
              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
          )
    else { return nil }

    context.setFillColor(gray: 0.08, alpha: 1)
    context.fill(CGRect(x: 0, y: 0, width: size, height: size))
    context.setFillColor(gray: 0.92, alpha: 1)
    let tile = 8
    for y in stride(from: 0, to: size, by: tile) {
        for x in stride(from: 0, to: size, by: tile) where (x / tile + y / tile).isMultiple(of: 2) {
            context.fill(CGRect(x: x, y: y, width: tile, height: tile))
        }
    }
    return context.makeImage()
}
