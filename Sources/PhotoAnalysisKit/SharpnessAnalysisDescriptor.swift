import Foundation

/// Stable identity for non-mask sharpness analysis output produced by
/// PhotoAnalysisKit.
///
/// The descriptor includes the configured ISO and aperture hint used when
/// capture metadata is absent. Actual capture metadata belongs to
/// `PhotoAnalysisInput`. The descriptor excludes focus-mask-only settings. Hosts should add decoded-image size,
/// source selection, and source-file identity when constructing persisted cache
/// keys.
public struct SharpnessAnalysisDescriptor: Codable, Equatable, Sendable {
    /// Encoding shape for this descriptor.
    public static let currentSchemaVersion = 2

    /// Scalar sharpness implementation revision.
    public static let currentAlgorithmVersion = 6

    /// Revision of the ISO-derived pre-blur scaling curve.
    public static let currentISOScalingPolicyVersion = 1

    /// Revision of aperture-hint blur-gate and weighting behavior.
    public static let currentApertureHintPolicyVersion = 1

    public let schemaVersion: Int
    public let algorithmVersion: Int
    public let isoScalingPolicyVersion: Int
    public let apertureHintPolicyVersion: Int

    /// Configured fallbacks. These fields are absent in schema version 1.
    public let fallbackISO: Int?
    public let fallbackApertureHint: SharpnessConfiguration.ApertureHint?
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
        self.fallbackISO = configuration.iso
        self.fallbackApertureHint = configuration.apertureHint
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
