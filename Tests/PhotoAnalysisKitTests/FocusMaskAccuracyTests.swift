import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins
import ImageIO
@testable import PhotoAnalysisKit
import Testing

@Suite("Focus mask accuracy")
struct FocusMaskAccuracyTests {
    @Test("Flat images cannot calibrate from artificial border edges", arguments: [64, 256])
    func flatCalibration(size: Int) async throws {
        let extent = CGRect(x: 0, y: 0, width: size, height: size)
        let context = FocusMaskEngine().context
        let image = try #require(context.createCGImage(
            CIImage(color: CIColor(red: 0.5, green: 0.5, blue: 0.5)).cropped(to: extent),
            from: extent
        ))
        let result = await PhotoAnalyzer().calibrate(
            from: [PhotoAnalysisInput(image: image)], minimumSuccessfulImages: 1
        )
        #expect(result == nil)
    }

    @Test("Calibration responds to real detail loss", arguments: [128, 256])
    func blurredCalibration(size: Int) async throws {
        let image = try #require(makeCheckerboardImage(size: size))
        let source = CIImage(cgImage: image)
        let blur = CIFilter.gaussianBlur()
        blur.inputImage = source.clampedToExtent()
        blur.radius = 3
        let blurred = try #require(blur.outputImage)
        let blurredImage = try #require(FocusMaskEngine().context.createCGImage(blurred, from: source.extent))
        let analyzer = PhotoAnalyzer()
        let sharpResult = try #require(await analyzer.calibrate(
            from: [PhotoAnalysisInput(image: image)], minimumSuccessfulImages: 1
        ))
        let blurredResult = try #require(await analyzer.calibrate(
            from: [PhotoAnalysisInput(image: blurredImage)], minimumSuccessfulImages: 1
        ))
        #expect(sharpResult.p90 > blurredResult.p90)

        var config = SharpnessConfiguration()
        config.threshold = sharpResult.threshold
        for sample in [image, blurredImage] {
            let result = await analyzer.analyzeWithFocusMask(
                PhotoAnalysisInput(image: sample, normalizedAFPoint: CGPoint(x: 0.5, y: 0.5)),
                configuration: config
            )
            #expect(result.breakdown?.focusMaskVisualThreshold == sharpResult.threshold)
        }
    }

    @Test(
        "AF scoring follows detail in rotated and mirrored decoded previews",
        arguments: [
            (CGImagePropertyOrientation.up, CGPoint(x: 0.25, y: 0.25)),
            (.right, CGPoint(x: 0.75, y: 0.25)),
            (.down, CGPoint(x: 0.75, y: 0.75)),
            (.upMirrored, CGPoint(x: 0.75, y: 0.25)),
            (.downMirrored, CGPoint(x: 0.25, y: 0.75))
        ]
    )
    func orientedAFRegion(orientation: CGImagePropertyOrientation, detailPoint: CGPoint) throws {
        let tile = try #require(makeCheckerboardImage(size: 128))
        let extent = CGRect(x: 0, y: 0, width: 256, height: 256)
        let base = CIImage(color: CIColor(red: 0.5, green: 0.5, blue: 0.5)).cropped(to: extent)
        let image = CIImage(cgImage: tile)
            .transformed(by: CGAffineTransform(translationX: 0, y: 128))
            .composited(over: base)
            .oriented(orientation)
        let engine = FocusMaskEngine()
        let preview = try #require(engine.context.createCGImage(image, from: image.extent))
        let noSaliency = SaliencyDetection(candidates: [], saliencyInfo: nil)

        func afScore(at point: CGPoint) throws -> Float {
            try #require(FocusMaskEngine.computeSharpnessBreakdown(
                from: CIImage(cgImage: preview),
                saliencyDetection: noSaliency,
                afPoint: point,
                context: engine.context,
                config: SharpnessConfiguration()
            )?.afPointScore)
        }

        let detail = try afScore(at: detailPoint)
        let flat = try afScore(at: CGPoint(x: 1 - detailPoint.x, y: 1 - detailPoint.y))
        #expect(detail > 0.01)
        #expect(flat < detail * 0.1)
    }

    @Test("Capture metadata overrides configured ISO and aperture only when present")
    func captureSettings() throws {
        let image = try #require(makeCheckerboardImage())
        var configuration = SharpnessConfiguration()
        configuration.iso = 1600
        configuration.apertureHint = .landscape

        let missing = PhotoAnalysisInput(image: image).resolvingCaptureSettings(in: configuration)
        #expect(missing.iso == 1600)
        #expect(missing.apertureHint == .landscape)
        let present = PhotoAnalysisInput(image: image, iso: 400, aperture: 4)
            .resolvingCaptureSettings(in: configuration)
        #expect(present.iso == 400)
        #expect(present.apertureHint == .wide)
    }

    @Test("A frame without subject evidence retains its global score")
    func frameOnlyScore() throws {
        let image = try #require(makeCheckerboardImage())
        let breakdown = try #require(FocusMaskEngine.computeSharpnessBreakdown(
            from: CIImage(cgImage: image),
            saliencyDetection: SaliencyDetection(candidates: [], saliencyInfo: nil),
            afPoint: nil, context: FocusMaskEngine().context, config: .birdsInFlight
        ))
        let globalScore = try #require(breakdown.globalScore)
        #expect(globalScore > 0)
        #expect(breakdown.finalScore == globalScore)
    }

    @Test("AF proximity cannot promote weak detail to high confidence")
    func weakAFConfidence() {
        let patch = FocusPatchRanking(
            normalizedRect: CGRect(x: 0.45, y: 0.45, width: 0.1, height: 0.1),
            robustTailScore: 0, microContrast: 0, coverage: 0,
            distanceToAF: 0, silhouetteFraction: 0, compositeScore: 0.12, containsAFPoint: true
        )
        let confidence = FocusMaskEngine.focusEvidenceConfidence(
            visualRegion: .afCenter, patches: [patch], afDistance: 0, dominance: 2, renderedCoverage: 0.5
        )
        #expect(confidence.value == .low)
    }

    @Test("Coverage reflects edges erased by requested erosion")
    func renderedCoverage() throws {
        let extent = CGRect(x: 0, y: 0, width: 32, height: 32)
        let line = CIImage(color: .white).cropped(to: CGRect(x: 16, y: 0, width: 1, height: 32))
            .composited(over: CIImage(color: .black).cropped(to: extent))
        let engine = FocusMaskEngine()
        var config = SharpnessConfiguration()
        let preserved = try #require(FocusMaskEngine.buildColorizedThresholdedEdges(from: line, threshold: 0.5, config: config))
        #expect(abs(FocusMaskEngine.renderedMaskCoverage(preserved, regions: [extent], extent: extent, context: engine.context) - 1.0 / 32) < 0.001)
        config.erosionRadius = 1
        let erased = try #require(FocusMaskEngine.buildColorizedThresholdedEdges(from: line, threshold: 0.5, config: config))
        #expect(FocusMaskEngine.renderedMaskCoverage(erased, regions: [extent], extent: extent, context: engine.context) == 0)
    }

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

    @Test("Frame inset is bounded before pixel conversion", arguments: [Float.nan, .infinity, -1, 0.75])
    func invalidBorderInset(inset: Float) throws {
        let image = try #require(makeCheckerboardImage())
        var config = SharpnessConfiguration()
        config.borderInsetFraction = inset
        let result = FocusMaskEngine.computeSharpnessBreakdown(
            from: CIImage(cgImage: image),
            saliencyDetection: SaliencyDetection(candidates: [], saliencyInfo: nil),
            afPoint: nil, context: FocusMaskEngine().context, config: config
        )
        #expect(result?.globalScore?.isFinite == true)
    }

    @Test("A constant image has no AF detail at the frame edge")
    func flatAFAtEdge() throws {
        let extent = CGRect(x: 0, y: 0, width: 128, height: 128)
        let image = CIImage(color: CIColor(red: 0.5, green: 0.5, blue: 0.5)).cropped(to: extent)
        let breakdown = try #require(FocusMaskEngine.computeSharpnessBreakdown(
            from: image,
            saliencyDetection: SaliencyDetection(candidates: [], saliencyInfo: nil),
            afPoint: CGPoint(x: 0.03, y: 0.03),
            context: FocusMaskEngine().context, config: SharpnessConfiguration()
        ))
        let afScore = try #require(breakdown.afPointScore)
        #expect(afScore < 0.0001)
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
