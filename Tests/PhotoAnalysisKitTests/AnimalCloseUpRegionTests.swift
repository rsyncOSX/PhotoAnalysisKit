import CoreGraphics
import Testing
@testable import PhotoAnalysisKit

@Suite("Animal close-up regions")
struct AnimalCloseUpRegionTests {
    @Test func `eye crops stay within the head and image`() throws {
        let eye = CGPoint(x: 5, y: 25)
        let regions = AnimalCloseUpDetector.crops(
            headPoints: [eye, CGPoint(x: 45, y: 25)],
            eyes: [eye, CGPoint(x: 90, y: 90)],
            in: CGRect(x: 0, y: 0, width: 100, height: 100)
        )
        try #require(regions.count == 2)
        #expect(regions[0].bounds.minX == 0)
        #expect(regions[1].bounds.minX == 0)
        #expect(regions[0].bounds.contains(regions[1].bounds))
    }

    @Test func `one landmark cannot establish a crop scale`() {
        let eye = CGPoint(x: 20, y: 20)
        #expect(AnimalCloseUpDetector.crops(
            headPoints: [eye], eyes: [eye], in: CGRect(x: 0, y: 0, width: 100, height: 100)
        ).isEmpty)
    }
}
