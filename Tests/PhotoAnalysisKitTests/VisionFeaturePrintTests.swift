import Foundation
import PhotoAnalysisKit
import Testing

@Suite("Vision feature prints")
struct VisionFeaturePrintTests {
    @Test("Equivalent images have a near-zero native distance")
    func equivalentImageDistance() async throws {
        let image = try #require(makeCheckerboardImage())
        let backend = VisionFeaturePrintBackend()
        let first = try await backend.featurePrint(for: image)
        let second = try await backend.featurePrint(for: image)

        let distance = try #require(try backend.distance(from: first, to: second))
        #expect(distance.isFinite)
        #expect(distance < 0.001)
        #expect(first.revision == second.revision)
        #expect(first.representationVersion == VisionFeaturePrint.currentRepresentationVersion)
    }

    @Test("Incompatible revisions are rejected without decoding")
    func incompatibleRevision() throws {
        let backend = VisionFeaturePrintBackend(revision: 2)
        let left = VisionFeaturePrint(revision: 2, payload: Data([1]))
        let right = VisionFeaturePrint(revision: 1, payload: Data([1]))
        #expect(try backend.distance(from: left, to: right) == nil)
    }

    @Test("Invalid compatible payload reports a decoding failure")
    func invalidPayload() {
        let backend = VisionFeaturePrintBackend(revision: 2)
        let invalid = VisionFeaturePrint(revision: 2, payload: Data([1, 2, 3]))
        #expect(throws: VisionFeaturePrintError.self) {
            _ = try backend.distance(from: invalid, to: invalid)
        }
    }

    @Test("Feature-print values round-trip through Codable")
    func codableRoundTrip() throws {
        let original = VisionFeaturePrint(revision: 2, payload: Data([4, 5, 6]))
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(VisionFeaturePrint.self, from: encoded)
        #expect(decoded == original)
    }
}
