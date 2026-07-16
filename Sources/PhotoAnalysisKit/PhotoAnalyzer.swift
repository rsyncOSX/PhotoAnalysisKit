import CoreGraphics
import Foundation

/// Immutable, reusable entry point for sharpness and focus-mask analysis.
///
/// The implementation is `@unchecked Sendable` only because Core Image does
/// not express `CIContext` sendability. `FocusMaskEngine` is immutable and its
/// context is safe to reuse concurrently; callers pass value snapshots into
/// every operation and no mutable UI or application state is retained.
public struct PhotoAnalyzer: @unchecked Sendable {
    private let engine: FocusMaskEngine

    public init() {
        self.engine = FocusMaskEngine()
    }

    /// Computes scalar sharpness, saliency/classification, and detailed focus
    /// evidence without rendering an overlay.
    public func analyze(
        _ input: PhotoAnalysisInput,
        configuration: SharpnessConfiguration = .birdsInFlight
    ) async -> PhotoAnalysisResult {
        var resolved = configuration
        resolved.iso = input.iso
        resolved.apertureHint = .from(aperture: input.aperture)

        let output = await engine.computeSharpnessScore(
            from: input.image,
            config: resolved,
            afPoint: input.normalizedAFPoint
        )
        return PhotoAnalysisResult(
            saliency: output.saliency,
            breakdown: output.breakdown,
            focusMask: nil
        )
    }

    /// Computes sharpness evidence and renders the corresponding focus mask.
    public func analyzeWithFocusMask(
        _ input: PhotoAnalysisInput,
        scale: CGFloat = 1,
        configuration: SharpnessConfiguration = .birdsInFlight
    ) async -> PhotoAnalysisResult {
        guard let normalizedImage = FocusMaskEngine.normalizeToSRGB(input.image) else {
            return PhotoAnalysisResult(saliency: nil, breakdown: nil, focusMask: nil)
        }
        var resolved = configuration
        resolved.iso = input.iso
        resolved.apertureHint = .from(aperture: input.aperture)

        let output = await engine.generateFocusMaskWithBreakdown(
            from: normalizedImage,
            scale: scale,
            config: resolved,
            afPoint: input.normalizedAFPoint
        )
        return PhotoAnalysisResult(
            saliency: output.saliency,
            breakdown: output.breakdown,
            focusMask: output.mask
        )
    }

    /// Renders a mask using previously computed evidence, avoiding a repeated
    /// saliency pass when a host already holds a `SharpnessBreakdown`.
    public func focusMask(
        for input: PhotoAnalysisInput,
        scale: CGFloat = 1,
        configuration: SharpnessConfiguration = .birdsInFlight,
        evidence: FocusEvidence? = nil
    ) async -> CGImage? {
        guard let normalizedImage = FocusMaskEngine.normalizeToSRGB(input.image) else {
            return nil
        }
        var resolved = configuration
        resolved.iso = input.iso
        resolved.apertureHint = .from(aperture: input.aperture)
        return await engine.generateFocusMask(
            from: normalizedImage,
            scale: scale,
            config: resolved,
            afPoint: input.normalizedAFPoint,
            evidence: evidence
        )
    }

    public func calibrate(
        from inputs: [PhotoAnalysisInput],
        baseConfiguration: SharpnessConfiguration = .birdsInFlight,
        thresholdPercentile: Float = 0.90,
        minimumSuccessfulImages: Int = 5,
        maximumConcurrentTasks: Int = 8
    ) async -> FocusCalibrationResult? {
        await engine.calibrate(
            inputs: inputs,
            baseConfig: baseConfiguration,
            thresholdPercentile: thresholdPercentile,
            minSamples: minimumSuccessfulImages,
            maxConcurrentTasks: maximumConcurrentTasks
        )
    }
}

/// Public numeric helpers used for diagnostics and deterministic unit tests.
public enum SharpnessMetrics {
    public static func robustTailScore(_ samples: [Float]) -> Float? {
        FocusMaskEngine.robustTailScore(samples)
    }

    public static func microContrast(_ samples: [Float]) -> Float {
        FocusMaskEngine.microContrast(samples)
    }

    public static func isoScalingFactor(iso: Int) -> Float {
        FocusMaskEngine.isoScalingFactor(iso: iso)
    }

    public static func classifyFocusFailure(
        globalScore: Float?,
        subjectScore: Float?,
        afPointScore: Float?,
        blurGateSigma: Float
    ) -> FocusFailureKind {
        FocusMaskEngine.classifyFocusFailure(
            globalScore: globalScore,
            subjectScore: subjectScore,
            afPointScore: afPointScore,
            blurGateSigma: blurGateSigma
        )
    }
}
