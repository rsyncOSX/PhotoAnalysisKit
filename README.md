# PhotoAnalysisKit

PhotoAnalysisKit is a neutral macOS image-analysis package extracted from
RawCull. It owns sharpness scoring, Vision saliency/classification, focus
evidence and mask rendering, calibration, and Vision feature-print generation
and comparison.

The package accepts `CGImage` values plus capture metadata. It deliberately has
no knowledge of RAW formats, file models, application settings, persistence,
cache locations, SwiftUI, or culling decisions.

The checked-in `default.metallib` is built from `Kernels.ci.metal` because
command-line SwiftPM copies Metal source resources but does not compile them.
After editing the kernel, regenerate it with `Tools/build_metallib.sh`.

## Requirements

- macOS 26 or newer
- Swift 6 language mode
- Apple Silicon is recommended for the Metal-backed sharpness pipeline

## Package product

- `PhotoAnalysisKit`: dependency-free image-analysis contracts and engines.

## Sharpness analysis

```swift
import PhotoAnalysisKit

let analyzer = PhotoAnalyzer()
let input = PhotoAnalysisInput(
    image: cgImage,
    iso: 800,
    aperture: 5.6,
    normalizedAFPoint: CGPoint(x: 0.5, y: 0.45)
)

let result = await analyzer.analyze(input)
print(result.breakdown?.finalScore as Any)
```

The host application remains responsible for decoding or demosaicing a source
file into a `CGImage`. This keeps camera-vendor behavior and security-scoped URL
handling outside the analysis package.

## Vision feature prints

```swift
let backend = VisionFeaturePrintBackend()
let left = try await backend.featurePrint(for: firstImage)
let right = try await backend.featurePrint(for: secondImage)
let distance = try backend.distance(from: left, to: right)
```

Feature prints retain the Vision request revision and a representation version,
so incompatible payloads are rejected before comparison.
