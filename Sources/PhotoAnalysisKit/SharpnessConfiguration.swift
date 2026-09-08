import Foundation

public struct SharpnessConfiguration: Sendable {
    /// Aperture-derived tuning hint. Wide-aperture shots have a narrow focus plane
    /// and deserve a stricter blur gate; landscape-aperture shots have deep DoF and
    /// should not be pre-blurred as aggressively nor weighted so heavily toward the
    /// Vision-detected salient region. `.mid` is the neutral baseline.
    /// Explicit nonisolated conformance — default-isolation=MainActor would otherwise
    /// make the synthesized Equatable.== main-isolated and unusable from the
    /// nonisolated scoring statics.
    public enum ApertureHint: Equatable, Sendable {
        case wide // ≤ f/5.6
        case mid // f/5.6–f/8
        case landscape // ≥ f/8

        public nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
            switch (lhs, rhs) {
            case (.wide, .wide), (.mid, .mid), (.landscape, .landscape): true
            default: false
            }
        }
    }

    public var preBlurRadius: Float = 1.92
    /// ISO at capture time. Used to scale preBlurRadius upward at high ISO
    /// where noise would otherwise cause the Laplacian to fire on noise rather
    /// than real edges. Default 400 (no adaptation).
    public var iso: Int = 400
    public var threshold: Float = 0.46
    public var dilationRadius: Float = 0.0
    public var energyMultiplier: Float = Self.stableScoringEnergyMultiplier
    public var erosionRadius: Float = 0.0
    public var featherRadius: Float = 0.5
    public var showRawLaplacian: Bool = false
    /// Retained for source compatibility. Rendering no longer relaxes its
    /// evidence threshold to force visibility on weak or unfocused images.
    public var guaranteeVisibleFocusEvidence: Bool = false
    public var minimumEvidenceCoverage: Float = 0.001
    public var afCenterRegionRadius: Float = 0.025
    public var afNeighborhoodRegionRadius: Float = 0.075

    /// When true, the visual focus-mask overlay is clipped to the detected subject
    /// region, falling back to the camera AF point if Vision does not find a subject.
    /// This is overlay-only; scalar scoring still uses the subject/full-frame blend.
    public var isolateMaskToSubject: Bool = true

    // MARK: Scoring-only parameters (do not affect the focus mask overlay)

    /// Fraction of image dimension excluded from each border when computing
    /// the full-frame sharpness score. Prevents Gaussian-blur edge artifacts
    /// from inflating the score. Range 0–0.10.
    public var borderInsetFraction: Float = 0.04

    /// Weight given to the salient-region score vs the full-frame score.
    /// 0 = full-frame only, 1 = subject region only.
    public var salientWeight: Float = 0.75

    /// Optional preset-level override for subject/full-frame blend weight.
    /// Takes precedence over aperture-derived overrides when set.
    public var explicitSalientWeightOverride: Float?

    /// Bonus multiplier for subject size.
    public var subjectSizeFactor: Float = 0.1

    /// Maximum reduction applied when a subject region is silhouette-dominated.
    /// 0 disables the penalty, 0.55 is the historical default.
    public var silhouettePenaltyStrength: Float = 0.55

    /// Optional second fine-detail Laplacian pass blended into scoring. Higher values
    /// cost more compute but preserve small subject detail at larger scoring sizes.
    /// The focus mask overlay keeps using the primary pass.
    public var fineDetailBlendWeight: Float = 0.0

    /// When true, runs VNClassifyImageRequest alongside saliency detection.
    public var enableSubjectClassification: Bool = true

    /// Half-size of the AF-point scoring region as a fraction of image dimension.
    public var afRegionRadius: Float = 0.12

    /// Aperture hint driving the soft blur-gate thresholds, the landscape blur damp,
    /// and the landscape salient-weight override. Set per-file by SharpnessScoringModel
    /// from EXIF; defaults to `.mid` when aperture is unknown.
    public var apertureHint: ApertureHint = .mid

    public static let stableScoringEnergyMultiplier: Float = 7.62

    public init() {}
}

extension SharpnessConfiguration.ApertureHint {
    /// Lower end of the soft blur-gate ramp. Below this subject-region σ, the final
    /// score is multiplied by 0.20 (strong, but no longer the old 0.12 cliff).
    public nonisolated var blurGateLow: Float {
        switch self {
        case .wide: 0.010
        case .mid: 0.008
        case .landscape: 0.006
        }
    }

    /// Upper end of the soft blur-gate ramp. Above this σ, no attenuation is applied.
    public nonisolated var blurGateHigh: Float {
        switch self {
        case .wide: 0.025
        case .mid: 0.022
        case .landscape: 0.018
        }
    }

    /// Multiplier applied to the combined ISO × resolution blur factor. Landscape damps
    /// so deep-DoF scenes with real whole-frame detail aren't pre-blurred away.
    public nonisolated var blurDamp: Float {
        switch self {
        case .wide, .mid: 1.0
        case .landscape: 0.8
        }
    }

    /// Overrides `config.salientWeight` when non-nil. Landscape reduces to 0.55 so that
    /// the Vision salient region does not dominate scoring on shots where the whole frame
    /// carries in-focus detail.
    public nonisolated var salientWeightOverride: Float? {
        switch self {
        case .wide, .mid: nil
        case .landscape: 0.55
        }
    }

    /// Derives the hint from an EXIF f-number for aperture-aware scoring.
    public nonisolated static func from(aperture: Double?) -> Self {
        guard let a = aperture else { return .mid }
        if a <= 5.6 {
            return .wide
        }
        if a >= 8.0 {
            return .landscape
        }
        return .mid
    }
}

// Explicit nonisolated conformance so the @Observable macro's change-tracking
// code can call == from a nonisolated context.
// swiftformat:disable:next redundantEquatable
extension SharpnessConfiguration: Equatable {
    public nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.preBlurRadius == rhs.preBlurRadius
            && lhs.iso == rhs.iso
            && lhs.threshold == rhs.threshold
            && lhs.dilationRadius == rhs.dilationRadius
            && lhs.energyMultiplier == rhs.energyMultiplier
            && lhs.erosionRadius == rhs.erosionRadius
            && lhs.featherRadius == rhs.featherRadius
            && lhs.showRawLaplacian == rhs.showRawLaplacian
            && lhs.guaranteeVisibleFocusEvidence == rhs.guaranteeVisibleFocusEvidence
            && lhs.minimumEvidenceCoverage == rhs.minimumEvidenceCoverage
            && lhs.afCenterRegionRadius == rhs.afCenterRegionRadius
            && lhs.afNeighborhoodRegionRadius == rhs.afNeighborhoodRegionRadius
            && lhs.isolateMaskToSubject == rhs.isolateMaskToSubject
            && lhs.borderInsetFraction == rhs.borderInsetFraction
            && lhs.salientWeight == rhs.salientWeight
            && lhs.explicitSalientWeightOverride == rhs.explicitSalientWeightOverride
            && lhs.subjectSizeFactor == rhs.subjectSizeFactor
            && lhs.silhouettePenaltyStrength == rhs.silhouettePenaltyStrength
            && lhs.fineDetailBlendWeight == rhs.fineDetailBlendWeight
            && lhs.enableSubjectClassification == rhs.enableSubjectClassification
            && lhs.afRegionRadius == rhs.afRegionRadius
            && lhs.apertureHint == rhs.apertureHint
    }
}

extension SharpnessConfiguration {
    /// Birds-in-flight preset.
    public nonisolated static var birdsInFlight: SharpnessConfiguration {
        var c = SharpnessConfiguration()
        c.preBlurRadius = 2.2
        c.threshold = 0.46
        c.dilationRadius = 0.0
        c.erosionRadius = 0.0
        c.featherRadius = 0.5

        c.borderInsetFraction = 0.05
        c.salientWeight = 0.85
        c.subjectSizeFactor = 0.05
        c.silhouettePenaltyStrength = 0.55
        c.enableSubjectClassification = true
        c.isolateMaskToSubject = true
        c.afRegionRadius = 0.06
        return c
    }
}
