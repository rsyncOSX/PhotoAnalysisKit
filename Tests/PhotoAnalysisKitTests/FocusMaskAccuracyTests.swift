import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins
@testable import PhotoAnalysisKit
import Testing

@Suite("Focus mask accuracy")
struct FocusMaskAccuracyTests {
    @Test("Default processing preserves a one-pixel edge")
    func thinEdge() throws {
        let extent = CGRect(x: 0, y: 0, width: 32, height: 32)
        let line = CIImage(color: .white).cropped(to: CGRect(x: 16, y: 0, width: 1, height: 32))
            .composited(over: CIImage(color: .black).cropped(to: extent))
        let engine = FocusMaskEngine()
        let mask = try #require(FocusMaskEngine.buildColorizedThresholdedEdges(
            from: line, threshold: 0.5, config: .birdsInFlight
        ))
        let samples = FocusMaskEngine.redSamples(in: extent, from: mask, context: engine.context)
        #expect(samples.filter { $0 > 0.5 }.count == 32)
    }

    @Test("Global mask covers detail beyond three representative patches")
    func globalCoverage() async throws {
        let image = try #require(makeCheckerboardImage(size: 256))
        var config = SharpnessConfiguration.birdsInFlight
        config.isolateMaskToSubject = false
        config.featherRadius = 0
        let engine = FocusMaskEngine()
        let mask = try #require(await engine.generateFocusMask(
            from: image, scale: 1, config: config,
            afPoint: CGPoint(x: 0.2, y: 0.2),
            evidence: FocusEvidence(winningRegion: .afCenter)
        ))
        let ci = CIImage(cgImage: mask)
        for y in [32, 160] {
            for x in [32, 160] {
                let samples = FocusMaskEngine.redSamples(
                    in: CGRect(x: x, y: y, width: 64, height: 64), from: ci, context: engine.context
                )
                #expect(samples.contains { $0 > 0.1 })
            }
        }
    }

    @Test("Constant image has no artificial border evidence")
    func constantImage() throws {
        let extent = CGRect(x: 0, y: 0, width: 64, height: 64)
        let image = CIImage(color: CIColor(red: 0.5, green: 0.5, blue: 0.5)).cropped(to: extent)
        let engine = FocusMaskEngine()
        let energy = try #require(FocusMaskEngine.buildAmplifiedLaplacian(
            from: image, config: .birdsInFlight, nativeMask: true
        ))
        let samples = FocusMaskEngine.redSamples(in: extent, from: energy, context: engine.context)
        #expect(samples.allSatisfy { abs($0) < 0.0001 })
    }
}
