import CoreGraphics
import Foundation
import Vision

/// An opaque, securely archived Vision feature print.
///
/// The Vision observation never crosses the package boundary. Persisting this
/// value is safe, but hosts remain responsible for associating it with source
/// file identity and invalidating their own caches when source data changes.
public struct VisionFeaturePrint: Codable, Equatable, Sendable {
    public static let currentRepresentationVersion = 1

    public let revision: Int
    public let representationVersion: Int
    public let payload: Data

    public init(
        revision: Int,
        representationVersion: Int = Self.currentRepresentationVersion,
        payload: Data
    ) {
        self.revision = revision
        self.representationVersion = representationVersion
        self.payload = payload
    }

    public func isCompatible(with other: Self) -> Bool {
        revision == other.revision
            && representationVersion == other.representationVersion
    }
}

/// Actor-owned Vision feature-print generation with package-owned comparison.
///
/// This implementation is intentionally equivalent to PhotoAIKit's proven
/// backend: revision 2 by default, secure observation archiving, and native
/// `VNFeaturePrintObservation.computeDistance` comparison.
public actor VisionFeaturePrintBackend {
    public nonisolated let revision: Int

    public init(revision: Int = VNGenerateImageFeaturePrintRequestRevision2) {
        self.revision = revision
    }

    public func featurePrint(for image: CGImage) async throws -> VisionFeaturePrint {
        try Task.checkCancellation()
        let request = VNGenerateImageFeaturePrintRequest()
        request.revision = revision
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        do {
            try handler.perform([request])
        } catch {
            throw VisionFeaturePrintError.generationFailed(String(describing: error))
        }
        try Task.checkCancellation()
        guard let observation = request.results?.first as? VNFeaturePrintObservation else {
            throw VisionFeaturePrintError.missingObservation
        }
        let payload: Data
        do {
            payload = try NSKeyedArchiver.archivedData(
                withRootObject: observation,
                requiringSecureCoding: true
            )
        } catch {
            throw VisionFeaturePrintError.encodingFailed(String(describing: error))
        }
        return VisionFeaturePrint(revision: revision, payload: payload)
    }

    public nonisolated func distance(
        from left: VisionFeaturePrint,
        to right: VisionFeaturePrint
    ) throws -> Float? {
        guard left.isCompatible(with: right),
              left.revision == revision,
              left.representationVersion == VisionFeaturePrint.currentRepresentationVersion
        else { return nil }

        let leftObservation = try Self.decode(left.payload)
        let rightObservation = try Self.decode(right.payload)
        var distance: Float = 0
        do {
            try leftObservation.computeDistance(&distance, to: rightObservation)
        } catch {
            throw VisionFeaturePrintError.comparisonFailed(String(describing: error))
        }
        guard distance.isFinite else {
            throw VisionFeaturePrintError.comparisonFailed(
                "Vision returned a non-finite distance."
            )
        }
        return distance
    }

    private nonisolated static func decode(_ data: Data) throws -> VNFeaturePrintObservation {
        do {
            guard let observation = try NSKeyedUnarchiver.unarchivedObject(
                ofClass: VNFeaturePrintObservation.self,
                from: data
            ) else { throw VisionFeaturePrintError.invalidPayload }
            return observation
        } catch let error as VisionFeaturePrintError {
            throw error
        } catch {
            throw VisionFeaturePrintError.decodingFailed(String(describing: error))
        }
    }
}

public enum VisionFeaturePrintError: Error, Equatable, Sendable {
    case generationFailed(String)
    case missingObservation
    case encodingFailed(String)
    case decodingFailed(String)
    case invalidPayload
    case comparisonFailed(String)
}
