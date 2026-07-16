import Foundation

/// Stable identity for non-mask sharpness analysis output produced by
/// PhotoAnalysisKit.
///
/// The descriptor deliberately excludes per-image values such as ISO and
/// aperture because those belong to `PhotoAnalysisInput`. It also excludes
/// focus-mask-only presentation settings. Hosts should add decoded-image size,
/// source selection, and source-file identity when constructing persisted cache
/// keys.
public struct SharpnessAnalysisDescriptor: Codable, Equatable, Sendable {
    /// Encoding shape for this descriptor.
    public static let currentSchemaVersion = 1

    /// Scalar sharpness implementation revision.
    ///
    /// Version 4 preserves RawCull's established cache identity at the point
    /// where ownership moved into PhotoAnalysisKit 1.1.0.
    public static let currentAlgorithmVersion = 4

    /// Revision of the ISO-derived pre-blur scaling curve.
    public static let currentISOScalingPolicyVersion = 1

    /// Revision of aperture-hint blur-gate and weighting behavior.
    public static let currentApertureHintPolicyVersion = 1

    public let schemaVersion: Int
    public let algorithmVersion: Int
    public let isoScalingPolicyVersion: Int
    public let apertureHintPolicyVersion: Int

    public let preBlurRadius: Float
    public let borderInsetFraction: Float
    public let salientWeight: Float
    public let explicitSalientWeightOverride: Float?
    public let subjectSizeFactor: Float
    public let silhouettePenaltyStrength: Float
    public let afRegionRadius: Float
    public let afCenterRegionRadius: Float
    public let afNeighborhoodRegionRadius: Float
    public let fineDetailBlendWeight: Float
    public let enableSubjectClassification: Bool
    public let stableScoringEnergyMultiplier: Float

    public init(
        configuration: SharpnessConfiguration,
        schemaVersion: Int = Self.currentSchemaVersion,
        algorithmVersion: Int = Self.currentAlgorithmVersion,
        isoScalingPolicyVersion: Int = Self.currentISOScalingPolicyVersion,
        apertureHintPolicyVersion: Int = Self.currentApertureHintPolicyVersion
    ) {
        self.schemaVersion = schemaVersion
        self.algorithmVersion = algorithmVersion
        self.isoScalingPolicyVersion = isoScalingPolicyVersion
        self.apertureHintPolicyVersion = apertureHintPolicyVersion
        self.preBlurRadius = configuration.preBlurRadius
        self.borderInsetFraction = configuration.borderInsetFraction
        self.salientWeight = configuration.salientWeight
        self.explicitSalientWeightOverride =
            configuration.explicitSalientWeightOverride
        self.subjectSizeFactor = configuration.subjectSizeFactor
        self.silhouettePenaltyStrength =
            configuration.silhouettePenaltyStrength
        self.afRegionRadius = configuration.afRegionRadius
        self.afCenterRegionRadius = configuration.afCenterRegionRadius
        self.afNeighborhoodRegionRadius =
            configuration.afNeighborhoodRegionRadius
        self.fineDetailBlendWeight = configuration.fineDetailBlendWeight
        self.enableSubjectClassification =
            configuration.enableSubjectClassification
        self.stableScoringEnergyMultiplier =
            SharpnessConfiguration.stableScoringEnergyMultiplier
    }
}
