import CoreGraphics
import Foundation

/// A decoded image and neutral capture metadata used by the analysis pipeline.
///
/// Coordinates are normalized to `0...1` with the origin at the visual
/// top-left, matching common camera AF metadata. The package performs
/// the Vision coordinate conversion internally.
public struct PhotoAnalysisInput: Sendable {
    public let image: CGImage
    public let iso: Int
    public let aperture: Double?
    public let normalizedAFPoint: CGPoint?

    public init(
        image: CGImage,
        iso: Int = 400,
        aperture: Double? = nil,
        normalizedAFPoint: CGPoint? = nil
    ) {
        self.image = image
        self.iso = max(1, iso)
        self.aperture = aperture
        self.normalizedAFPoint = normalizedAFPoint
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
