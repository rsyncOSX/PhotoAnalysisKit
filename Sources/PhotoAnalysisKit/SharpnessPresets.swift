import Foundation

/// Optional high-level tuning. Hosts can instead edit `SharpnessConfiguration`
/// directly and persist their own settings representation.
public enum SharpnessPreset: String, CaseIterable, Codable, Sendable {
    case automatic
    case birdsAndWildlife
    case portrait
    case landscape
    case generalAction

    public func applying(to configuration: SharpnessConfiguration) -> SharpnessConfiguration {
        var result = configuration
        switch self {
        case .automatic:
            return result
        case .birdsAndWildlife:
            result.preBlurRadius = 2.2
            result.borderInsetFraction = 0.05
            result.salientWeight = 0.85
            result.explicitSalientWeightOverride = 0.85
            result.subjectSizeFactor = 0.05
            result.silhouettePenaltyStrength = 0.55
            result.afRegionRadius = 0.06
            result.enableSubjectClassification = true
            result.isolateMaskToSubject = true
        case .portrait:
            result.preBlurRadius = min(result.preBlurRadius, 1.7)
            result.salientWeight = 0.80
            result.explicitSalientWeightOverride = 0.80
            result.subjectSizeFactor = 0.08
            result.silhouettePenaltyStrength = 0.25
            result.afRegionRadius = 0.10
            result.enableSubjectClassification = true
            result.isolateMaskToSubject = true
        case .landscape:
            result.preBlurRadius = min(result.preBlurRadius, 1.55)
            result.salientWeight = 0.35
            result.explicitSalientWeightOverride = 0.35
            result.subjectSizeFactor = 0
            result.silhouettePenaltyStrength = 0.15
            result.afRegionRadius = 0
            result.isolateMaskToSubject = false
        case .generalAction:
            result.preBlurRadius = 2.0
            result.salientWeight = 0.65
            result.explicitSalientWeightOverride = 0.65
            result.subjectSizeFactor = 0.05
            result.silhouettePenaltyStrength = 0.40
            result.afRegionRadius = 0.09
            result.enableSubjectClassification = true
            result.isolateMaskToSubject = true
        }
        return result
    }
}

public enum SharpnessQuality: String, CaseIterable, Codable, Sendable {
    case fast
    case balanced
    case highPrecision

    public func applying(to configuration: SharpnessConfiguration) -> SharpnessConfiguration {
        var result = configuration
        switch self {
        case .fast:
            result.fineDetailBlendWeight = 0
        case .balanced:
            result.fineDetailBlendWeight = max(result.fineDetailBlendWeight, 0.25)
        case .highPrecision:
            result.fineDetailBlendWeight = max(result.fineDetailBlendWeight, 0.45)
            result.enableSubjectClassification = true
        }
        return result
    }
}
