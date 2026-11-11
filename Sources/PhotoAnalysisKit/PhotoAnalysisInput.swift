import CoreGraphics
import Foundation

/// A decoded image and neutral capture metadata used by the analysis pipeline.
///
/// Coordinates are normalized to `0...1` with the origin at the visual
/// top-left, matching common camera AF metadata. The package performs
/// the Vision coordinate conversion internally.
public struct PhotoAnalysisInput: Sendable {
    public let image: CGImage
    /// Capture ISO, or 400 when unavailable. Analysis uses its configured ISO
    /// when the caller omits capture ISO.
    public let iso: Int
    let captureISO: Int?
    public let aperture: Double?
    public let normalizedAFPoint: CGPoint?

    public init(
        image: CGImage,
        aperture: Double? = nil,
        normalizedAFPoint: CGPoint? = nil
    ) {
        self.init(image: image, captureISO: nil, aperture: aperture, normalizedAFPoint: normalizedAFPoint)
    }

    public init(
        image: CGImage,
        iso: Int,
        aperture: Double? = nil,
        normalizedAFPoint: CGPoint? = nil
    ) {
        self.init(image: image, captureISO: max(1, iso), aperture: aperture, normalizedAFPoint: normalizedAFPoint)
    }

    private init(
        image: CGImage,
        captureISO: Int?,
        aperture: Double? = nil,
        normalizedAFPoint: CGPoint? = nil
    ) {
        self.image = image
        self.captureISO = captureISO
        self.iso = self.captureISO ?? 400
        self.aperture = aperture
        self.normalizedAFPoint = normalizedAFPoint
    }

    func resolvingCaptureSettings(in configuration: SharpnessConfiguration) -> SharpnessConfiguration {
        var resolved = configuration
        resolved.iso = captureISO ?? configuration.iso
        if let aperture, aperture.isFinite, aperture > 0 {
            resolved.apertureHint = .from(aperture: aperture)
        }
        return resolved
    }
}

public struct PhotoAnalysisResult: Sendable {
    public let saliency: SaliencySummary?
    public let breakdown: SharpnessBreakdown?
    public let focusMask: CGImage?

    public init(
        saliency: SaliencySummary?,
        breakdown: SharpnessBreakdown?,
        focusMask: CGImage?
    ) {
        self.saliency = saliency
        self.breakdown = breakdown
        self.focusMask = focusMask
    }

    public var score: Float? {
        breakdown?.finalScore
    }
}
