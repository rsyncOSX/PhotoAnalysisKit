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

## Sharpness configuration and cache identity

PhotoAnalysisKit owns the numeric tuning applied by `SharpnessPreset` and
`SharpnessQuality`. Hosts may keep their own persisted or presentation enums,
but should map them to these package values instead of duplicating the tuning
constants.

Hosts that persist sharpness results can use the package-owned descriptor:

```swift
let configuration = SharpnessQuality.balanced.applying(
    to: SharpnessPreset.birdsAndWildlife.applying(
        to: .birdsInFlight
    )
)
let descriptor = PhotoAnalyzer.sharpnessDescriptor(
    for: configuration
)
```

`SharpnessAnalysisDescriptor` contains the package algorithm and policy
versions plus every host-configurable value that affects non-mask sharpness
analysis output. Per-image ISO and aperture remain part of `PhotoAnalysisInput`.
Applications should layer source-selection, decoded-image size, and source-file
identity around this descriptor when building their cache keys.

The host application remains responsible for decoding or demosaicing a source
file into a `CGImage`. This keeps camera-vendor behavior and security-scoped URL
handling outside the analysis package.

## Batch analysis

PhotoAnalysisKit can coordinate bounded concurrent analysis without taking
ownership of file decoding. Each request supplies an asynchronous input provider,
so hosts retain their RAW/JPEG loading policy:

```swift
let requests = files.map { file in
    PhotoAnalysisBatchRequest(id: file.id) {
        guard let image = await decode(file.url) else { return nil }
        return PhotoAnalysisInput(
            image: image,
            iso: file.iso,
            aperture: file.aperture
        )
    }
}

let results = await analyzer.analyzeBatch(
    requests,
    maximumConcurrentTasks: 4
) { progress in
    print("\(progress.completedCount)/\(progress.totalCount)")
}
```

The returned array preserves request order even though progress is reported in
completion order. A `nil` return means the parent task was cancelled; individual
decode failures remain represented by a batch result whose `analysis` is `nil`.

## Vision feature prints

```swift
let backend = VisionFeaturePrintBackend()
let left = try await backend.featurePrint(for: firstImage)
let right = try await backend.featurePrint(for: secondImage)
let distance = try backend.distance(from: left, to: right)
```

Feature prints retain the Vision request revision and a representation version,
so incompatible payloads are rejected before comparison.
