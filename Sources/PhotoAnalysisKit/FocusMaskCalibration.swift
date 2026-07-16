import CoreImage
import Foundation

public struct FocusCalibrationResult: Equatable, Sendable {
    public let threshold: Float
    public let sampleCount: Int
    public let p50: Float
    public let p90: Float
    public let p95: Float
    public let p99: Float

    public init(
        threshold: Float,
        sampleCount: Int,
        p50: Float,
        p90: Float,
        p95: Float,
        p99: Float
    ) {
        self.threshold = threshold
        self.sampleCount = sampleCount
        self.p50 = p50
        self.p90 = p90
        self.p95 = p95
        self.p99 = p99
    }
}

extension FocusMaskEngine {
    /// Calibrates only the visual edge threshold from sampled Laplacian pixel energies.
    /// Core sharpness scores keep a fixed gain and therefore do not depend on catalog contents.
    nonisolated func calibrate(
        inputs: [PhotoAnalysisInput],
        baseConfig: SharpnessConfiguration,
        thresholdPercentile: Float = 0.90,
        minSamples: Int = 5,
        maxConcurrentTasks: Int = 8
    ) async -> FocusCalibrationResult? {
        guard !inputs.isEmpty else { return nil }
        let concurrency = max(1, min(maxConcurrentTasks, inputs.count))
        let context = self.context
        var nextIndex = 0
        var successfulImages = 0
        var energies = [Float]()

        await withTaskGroup(of: [Float]?.self) { group in
            func enqueue(_ input: PhotoAnalysisInput) {
                group.addTask { [baseConfig, context] in
                    guard !Task.isCancelled else { return nil }
                    var fileConfig = baseConfig
                    fileConfig.iso = input.iso
                    fileConfig.apertureHint = .from(aperture: input.aperture)
                    fileConfig.enableSubjectClassification = false
                    guard let normalizedImage = Self.normalizeToSRGB(input.image),
                          let laplacian = Self.buildAmplifiedLaplacian(
                        from: CIImage(cgImage: normalizedImage),
                        config: fileConfig,
                    ) else { return nil }
                    guard !Task.isCancelled else { return nil }
                    let samples = Self.redSamples(in: laplacian.extent, from: laplacian, context: context)
                        .filter { $0.isFinite && $0 > 0 }
                    guard !Task.isCancelled else { return nil }
                    let strideBy = max(samples.count / 4096, 1)
                    return Swift.stride(from: 0, to: samples.count, by: strideBy).map { samples[$0] }
                }
            }
            for _ in 0 ..< concurrency where nextIndex < inputs.count && !Task.isCancelled {
                enqueue(inputs[nextIndex])
                nextIndex += 1
            }
            while let values = await group.next() {
                guard !Task.isCancelled else {
                    group.cancelAll()
                    break
                }
                if let values, !values.isEmpty {
                    successfulImages += 1
                    energies.append(contentsOf: values)
                }
                if nextIndex < inputs.count, !Task.isCancelled {
                    enqueue(inputs[nextIndex])
                    nextIndex += 1
                }
            }
        }

        guard !Task.isCancelled, successfulImages >= minSamples, !energies.isEmpty else { return nil }
        energies.sort()
        func percentile(_ p: Float) -> Float {
            let index = Int((Float(energies.count - 1) * min(max(p, 0), 1)).rounded(.toNearestOrEven))
            return energies[index]
        }
        return FocusCalibrationResult(
            threshold: min(max(percentile(thresholdPercentile), 0.01), 0.95),
            sampleCount: energies.count,
            p50: percentile(0.50),
            p90: percentile(0.90),
            p95: percentile(0.95),
            p99: percentile(0.99),
        )
    }
}
