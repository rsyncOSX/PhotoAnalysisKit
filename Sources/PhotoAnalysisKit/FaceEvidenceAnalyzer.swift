import CoreGraphics
import Foundation
import Vision

/// An observation in an upright decoded preview. IDs are local to one result.
public struct FaceEvidence: Codable, Equatable, Sendable, Identifiable {
    public let id: Int
    /// Normalized rectangle with a visual top-left origin.
    public let normalizedBounds: CGRect
    /// Mean squared luminance gradient in the interior of the face.
    /// Compare similar captures of the same face at compatible preview scales.
    public let localDetail: Double?
}

public struct FaceEvidenceResult: Codable, Equatable, Sendable {
    public let algorithmVersion: Int
    public let detectorRevision: Int
    public let previewWidth: Int
    public let previewHeight: Int
    public let faces: [FaceEvidence]
}

/// Analyzes an orientation-corrected preview. Apply EXIF rotation and mirroring
/// before calling, and supply the same upright preview when rendering close-ups.
public actor FaceEvidenceAnalyzer {
    public init() {}

    /// Returns an empty list for a successful scan with no faces.
    /// Vision and cancellation failures propagate to the caller.
    public func analyze(_ uprightPreview: CGImage) throws -> FaceEvidenceResult {
        try Task.checkCancellation()
        let request = VNDetectFaceRectanglesRequest()
        try VNImageRequestHandler(cgImage: uprightPreview, orientation: .up).perform([request])
        var boxes = (request.results ?? []).compactMap {
            Self.topLeftBounds(fromVision: $0.boundingBox)
        }
        if boxes.allSatisfy({ max($0.width, $0.height) < 0.10 }) {
            try Self.findSmallFaces(in: uprightPreview, revision: request.revision, addingTo: &boxes)
        }
        boxes.sort {
            [$0.minY, $0.minX, $0.width, $0.height]
                .lexicographicallyPrecedes([$1.minY, $1.minX, $1.width, $1.height])
        }

        var faces: [FaceEvidence] = []
        for (id, bounds) in boxes.enumerated() {
            try Task.checkCancellation()
            faces.append(FaceEvidence(
                id: id,
                normalizedBounds: bounds,
                localDetail: Self.measureDetail(in: uprightPreview, bounds: bounds)
            ))
        }
        try Task.checkCancellation()
        return FaceEvidenceResult(
            algorithmVersion: 2,
            detectorRevision: request.revision,
            previewWidth: uprightPreview.width,
            previewHeight: uprightPreview.height,
            faces: faces
        )
    }

    private static func findSmallFaces(in preview: CGImage, revision: Int, addingTo boxes: inout [CGRect]) throws {
        let width = CGFloat(preview.width)
        let height = CGFloat(preview.height)
        guard max(width, height) >= 1024 else { return }
        let imageBounds = CGRect(x: 0, y: 0, width: width, height: height)
        // Overlap tiles so a face split by one boundary is visible in another tile.
        for y in [0.0, 0.4] {
            for x in [0.0, 0.4] {
                try Task.checkCancellation()
                let rect = CGRect(x: x * width, y: y * height,
                                  width: 0.6 * width, height: 0.6 * height).integral.intersection(imageBounds)
                guard let tile = preview.cropping(to: rect) else { continue }
                let request = VNDetectFaceRectanglesRequest()
                request.revision = revision
                try VNImageRequestHandler(cgImage: tile, orientation: .up).perform([request])
                for face in request.results ?? [] {
                    guard let local = topLeftBounds(fromVision: face.boundingBox),
                          // Ignore partial faces at artificial tile boundaries.
                          rect.minX == 0 || local.minX > 0.02,
                          rect.minY == 0 || local.minY > 0.02,
                          rect.maxX == width || local.maxX < 0.98,
                          rect.maxY == height || local.maxY < 0.98 else { continue }
                    let box = CGRect(x: (rect.minX + local.minX * rect.width) / width,
                                     y: (rect.minY + local.minY * rect.height) / height,
                                     width: local.width * rect.width / width,
                                     height: local.height * rect.height / height)
                    let duplicate = boxes.contains { existing in
                        let overlap = existing.intersection(box)
                        return !overlap.isEmpty && overlap.width * overlap.height >=
                            0.5 * min(existing.width * existing.height, box.width * box.height)
                    }
                    if !duplicate { boxes.append(box) }
                }
            }
        }
    }

    static func topLeftBounds(fromVision bounds: CGRect) -> CGRect? {
        guard [bounds.minX, bounds.minY, bounds.width, bounds.height].allSatisfy(\.isFinite) else {
            return nil
        }
        let clipped = bounds.intersection(CGRect(x: 0, y: 0, width: 1, height: 1))
        guard !clipped.isEmpty else { return nil }
        return CGRect(x: clipped.minX, y: 1 - clipped.maxY, width: clipped.width, height: clipped.height)
    }

    static func measureDetail(in image: CGImage, bounds: CGRect) -> Double? {
        let imageWidth = CGFloat(image.width)
        let imageHeight = CGFloat(image.height)
        let face = CGRect(x: bounds.minX * imageWidth, y: bounds.minY * imageHeight,
                          width: bounds.width * imageWidth, height: bounds.height * imageHeight)
        let interior = face.insetBy(dx: face.width * 0.15, dy: face.height * 0.15)
        guard interior.width >= 32, interior.height >= 32,
              let crop = image.cropping(to: interior.integral) else { return nil }

        let scale = min(1, 256.0 / Double(max(crop.width, crop.height)))
        let width = max(3, Int(Double(crop.width) * scale))
        let height = max(3, Int(Double(crop.height) * scale))
        var luminance = [UInt8](repeating: 0, count: width * height)
        return luminance.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(
                data: buffer.baseAddress, width: width, height: height,
                bitsPerComponent: 8, bytesPerRow: width, space: CGColorSpaceCreateDeviceGray(),
                bitmapInfo: CGImageAlphaInfo.none.rawValue
            ) else { return nil }
            context.interpolationQuality = .high
            context.draw(crop, in: CGRect(x: 0, y: 0, width: width, height: height))

            let pixels = buffer.bindMemory(to: UInt8.self)
            var energy = 0
            for y in 1..<(height - 1) {
                for x in 1..<(width - 1) {
                    let index = y * width + x
                    let horizontal = Int(pixels[index + 1]) - Int(pixels[index - 1])
                    let vertical = Int(pixels[index + width]) - Int(pixels[index - width])
                    energy += horizontal * horizontal + vertical * vertical
                }
            }
            return Double(energy) / Double((width - 2) * (height - 2)) / (2 * 255 * 255)
        }
    }
}
