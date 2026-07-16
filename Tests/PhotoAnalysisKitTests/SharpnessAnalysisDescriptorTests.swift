import Foundation
import PhotoAnalysisKit
import Testing

@Suite("Sharpness analysis descriptor")
struct SharpnessAnalysisDescriptorTests {
    @Test("PhotoAnalyzer returns the package descriptor")
    func analyzerDescriptor() {
        let configuration = SharpnessConfiguration.birdsInFlight

        #expect(
            PhotoAnalyzer.sharpnessDescriptor(for: configuration)
                == SharpnessAnalysisDescriptor(configuration: configuration)
        )
    }

    @Test("Descriptor round-trips through Codable")
    func codableRoundTrip() throws {
        let original = SharpnessAnalysisDescriptor(
            configuration: .birdsInFlight
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(
            SharpnessAnalysisDescriptor.self,
            from: data
        )

        #expect(decoded == original)
    }

    @Test(
        "Every non-mask analysis setting changes cache identity",
        arguments: ScoringMutation.allCases
    )
    func scoringMutationChangesIdentity(_ mutation: ScoringMutation) {
        let baseline = SharpnessConfiguration.birdsInFlight
        var changed = baseline
        mutation.apply(to: &changed)

        #expect(
            SharpnessAnalysisDescriptor(configuration: baseline)
                != SharpnessAnalysisDescriptor(configuration: changed)
        )
    }

    @Test("Focus-mask-only settings do not change scalar cache identity")
    func overlaySettingsDoNotChangeIdentity() {
        let baseline = SharpnessConfiguration.birdsInFlight
        var changed = baseline
        changed.threshold += 0.1
        changed.dilationRadius += 0.5
        changed.erosionRadius += 0.5
        changed.featherRadius += 0.5
        changed.showRawLaplacian.toggle()
        changed.guaranteeVisibleFocusEvidence.toggle()
        changed.minimumEvidenceCoverage += 0.01
        changed.isolateMaskToSubject.toggle()
        changed.energyMultiplier += 1

        #expect(
            SharpnessAnalysisDescriptor(configuration: baseline)
                == SharpnessAnalysisDescriptor(configuration: changed)
        )
    }

    @Test("Descriptor owns the established algorithm policy versions")
    func currentVersions() {
        let descriptor = SharpnessAnalysisDescriptor(
            configuration: .birdsInFlight
        )

        #expect(
            descriptor.schemaVersion
                == SharpnessAnalysisDescriptor.currentSchemaVersion
        )
        #expect(
            descriptor.algorithmVersion
                == SharpnessAnalysisDescriptor.currentAlgorithmVersion
        )
        #expect(
            descriptor.isoScalingPolicyVersion
                == SharpnessAnalysisDescriptor.currentISOScalingPolicyVersion
        )
        #expect(
            descriptor.apertureHintPolicyVersion
                == SharpnessAnalysisDescriptor
                .currentApertureHintPolicyVersion
        )
    }
}

enum ScoringMutation: CaseIterable, Sendable {
    case preBlurRadius
    case borderInsetFraction
    case salientWeight
    case explicitSalientWeightOverride
    case subjectSizeFactor
    case silhouettePenaltyStrength
    case afRegionRadius
    case afCenterRegionRadius
    case afNeighborhoodRegionRadius
    case fineDetailBlendWeight
    case enableSubjectClassification

    func apply(to configuration: inout SharpnessConfiguration) {
        switch self {
        case .preBlurRadius:
            configuration.preBlurRadius += 0.1
        case .borderInsetFraction:
            configuration.borderInsetFraction += 0.01
        case .salientWeight:
            configuration.salientWeight -= 0.1
        case .explicitSalientWeightOverride:
            configuration.explicitSalientWeightOverride = 0.5
        case .subjectSizeFactor:
            configuration.subjectSizeFactor += 0.1
        case .silhouettePenaltyStrength:
            configuration.silhouettePenaltyStrength -= 0.1
        case .afRegionRadius:
            configuration.afRegionRadius += 0.01
        case .afCenterRegionRadius:
            configuration.afCenterRegionRadius += 0.01
        case .afNeighborhoodRegionRadius:
            configuration.afNeighborhoodRegionRadius += 0.01
        case .fineDetailBlendWeight:
            configuration.fineDetailBlendWeight += 0.1
        case .enableSubjectClassification:
            configuration.enableSubjectClassification.toggle()
        }
    }
}
