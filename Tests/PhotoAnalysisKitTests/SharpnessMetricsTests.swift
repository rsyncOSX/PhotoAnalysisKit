import Foundation
import PhotoAnalysisKit
import Testing

@Suite("Sharpness numeric metrics")
struct SharpnessMetricsTests {
    @Test("Empty robust-tail input returns nil")
    func emptyRobustTail() {
        #expect(SharpnessMetrics.robustTailScore([]) == nil)
    }

    @Test("Uniform robust-tail input returns zero")
    func uniformRobustTail() throws {
        let samples = [Float](repeating: 0.5, count: 1_000)
        let score = try #require(SharpnessMetrics.robustTailScore(samples))
        #expect(score < 1e-5)
    }

    @Test("Dense edge samples score above sparse samples")
    func denseEdgesBeatSparseEdges() throws {
        let count = 1_000
        let dense = (0 ..< count).map { Float($0) / Float(count - 1) }
        var sparse = [Float](repeating: 0, count: 950)
        sparse += [Float](repeating: 1, count: 50)

        let denseScore = try #require(SharpnessMetrics.robustTailScore(dense))
        let sparseScore = try #require(SharpnessMetrics.robustTailScore(sparse))
        #expect(denseScore > sparseScore)
    }

    @Test("Robust-tail score scales proportionally")
    func robustTailScaleProportional() throws {
        let count = 1_000
        let base = (0 ..< count).map { Float($0) / Float(count - 1) }
        let scaled = base.map { $0 * 10 }
        let first = try #require(SharpnessMetrics.robustTailScore(base))
        let second = try #require(SharpnessMetrics.robustTailScore(scaled))
        #expect(abs(second / first - 10) < 0.1)
    }

    @Test("Alternating samples have expected micro-contrast")
    func alternatingMicroContrast() {
        let samples: [Float] = (0 ..< 1_000).map { $0.isMultiple(of: 2) ? 0 : 1 }
        #expect(abs(SharpnessMetrics.microContrast(samples) - 0.5) < 0.01)
    }

    @Test("Micro-contrast ignores non-finite samples")
    func microContrastIgnoresNonFiniteSamples() {
        var samples = [Float](repeating: 0.5, count: 100)
        samples.append(.nan)
        samples.append(.infinity)
        #expect(SharpnessMetrics.microContrast(samples) < 1e-5)
    }

    @Test(
        "ISO scaling follows the stable curve",
        arguments: [
            (100, Float(1.0)),
            (400, Float(1.0)),
            (800, Float(1.0)),
            (2_000, Float(1.3)),
            (3_200, Float(1.6)),
            (12_800, Float(2.2)),
            (51_200, Float(2.2))
        ]
    )
    func isoScaling(iso: Int, expected: Float) {
        #expect(abs(SharpnessMetrics.isoScalingFactor(iso: iso) - expected) < 1e-4)
    }

    @Test("ISO scaling is monotonic and remains below the legacy curve")
    func isoScalingPolicy() {
        let isoValues = [
            100, 200, 400, 800, 1_600, 2_000, 3_200, 6_400, 12_800, 25_600,
        ]
        let factors = isoValues.map {
            SharpnessMetrics.isoScalingFactor(iso: $0)
        }

        for index in 1 ..< factors.count {
            #expect(factors[index] >= factors[index - 1])
        }
        #expect(SharpnessMetrics.isoScalingFactor(iso: 6_400) < 2)
    }

    @Test(
        "Failure classification distinguishes blur and missed focus",
        arguments: [
            (Float(0.03), Float(0.04), Float(0.05), Float(0.004), FocusFailureKind.motionBlur),
            (Float(0.30), Float(0.10), Float(0.11), Float(0.03), FocusFailureKind.missedFocus),
            (Float(0.24), Float(0.22), Float(0.26), Float(0.03), FocusFailureKind.none)
        ]
    )
    func failureClassification(
        global: Float,
        subject: Float,
        af: Float,
        sigma: Float,
        expected: FocusFailureKind
    ) {
        #expect(SharpnessMetrics.classifyFocusFailure(
            globalScore: global,
            subjectScore: subject,
            afPointScore: af,
            blurGateSigma: sigma
        ) == expected)
    }
}

@Suite("Sharpness configuration")
struct SharpnessConfigurationTests {
    @Test(
        "Aperture maps to the expected hint",
        arguments: [
            (Optional<Double>.none, SharpnessConfiguration.ApertureHint.mid),
            (2.8, .wide),
            (5.6, .wide),
            (6.3, .mid),
            (8.0, .landscape),
            (16.0, .landscape)
        ]
    )
    func apertureHint(aperture: Double?, expected: SharpnessConfiguration.ApertureHint) {
        #expect(.from(aperture: aperture) == expected)
    }

    @Test("Aperture hints preserve blur-gate and weighting policy")
    func aperturePolicy() {
        let hints = [
            SharpnessConfiguration.ApertureHint.wide,
            .mid,
            .landscape,
        ]
        for hint in hints {
            #expect(hint.blurGateHigh > hint.blurGateLow)
        }

        #expect(SharpnessConfiguration.ApertureHint.landscape.blurGateLow
            < SharpnessConfiguration.ApertureHint.mid.blurGateLow)
        #expect(SharpnessConfiguration.ApertureHint.mid.blurGateLow
            < SharpnessConfiguration.ApertureHint.wide.blurGateLow)
        #expect(SharpnessConfiguration.ApertureHint.wide.salientWeightOverride == nil)
        #expect(SharpnessConfiguration.ApertureHint.mid.salientWeightOverride == nil)
        #expect(SharpnessConfiguration.ApertureHint.landscape.salientWeightOverride == 0.55)
        #expect(SharpnessConfiguration.ApertureHint.landscape.blurDamp == 0.8)
    }

    @Test("Presets preserve their scoring emphasis")
    func presets() {
        let base = SharpnessConfiguration.birdsInFlight
        let wildlife = SharpnessPreset.birdsAndWildlife.applying(to: base)
        let portrait = SharpnessPreset.portrait.applying(to: base)
        let landscape = SharpnessPreset.landscape.applying(to: base)

        #expect(wildlife.afRegionRadius == 0.06)
        #expect(wildlife.explicitSalientWeightOverride == 0.85)
        #expect(portrait.silhouettePenaltyStrength < wildlife.silhouettePenaltyStrength)
        #expect(landscape.afRegionRadius == 0)
        #expect(!landscape.isolateMaskToSubject)
    }

    @Test("Quality levels increase fine-detail analysis")
    func quality() {
        let base = SharpnessConfiguration()
        #expect(SharpnessQuality.fast.applying(to: base).fineDetailBlendWeight == 0)
        #expect(SharpnessQuality.balanced.applying(to: base).fineDetailBlendWeight == 0.25)
        #expect(SharpnessQuality.highPrecision.applying(to: base).fineDetailBlendWeight == 0.45)
    }
}
