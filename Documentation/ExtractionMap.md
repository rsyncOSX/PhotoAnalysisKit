# Extraction map

This document records the initial RawCull and PhotoAIKit extraction boundary.

## Sharpness and focus analysis

| Original responsibility | PhotoAnalysisKit destination | Boundary decision |
|---|---|---|
| `FocusMaskEngine` and scoring extension | `FocusMaskEngine*` plus `PhotoAnalyzer` | Package owns immutable Core Image/Vision/Metal analysis. |
| `FocusDetectorConfig` | `SharpnessConfiguration` | Renamed and made public; contains algorithm settings only. |
| Sharpness photo/quality presets | `SharpnessPreset`, `SharpnessQuality` | Display wording and settings persistence remain in hosts. |
| `FocusMaskTypes` | Package result/evidence types | RawCullCore `SaliencyInfo` was replaced by neutral `SaliencySummary`. |
| `FocusMaskCalibration` | `PhotoAnalyzer.calibrate` | Accepts decoded `PhotoAnalysisInput` values rather than URLs. |
| `Kernels.ci.metal` | Package resources | Source and generated Core Image `default.metallib` are package-owned. |
| `SharpnessScoringModel` | Not packaged | Observable state, progress, task ownership, sorting, and `FileItem` mapping remain host concerns. |
| RAW/embedded-preview decoding | Not packaged | Hosts decode with RawParserKit, ImageIO, or another decoder and pass a `CGImage`. |

## Vision feature prints

| PhotoAIKit responsibility | PhotoAnalysisKit destination | Boundary decision |
|---|---|---|
| Vision request and secure observation archive | `VisionFeaturePrintBackend.featurePrint` | Behavior retained with Vision revision 2 as the default. |
| Native Vision distance calculation | `VisionFeaturePrintBackend.distance` | Incompatible revision/representation pairs return `nil`. |
| `SimilarityArtifact` and source fingerprints | Not copied | Host applications own source-file identity and cache invalidation. |
| CLIP fallback and batch indexing | Not copied | These remain PhotoAIKit AI workflow responsibilities. |

## Deliberate package exclusions

- `FileItem`, `RawCullViewModel`, and `SettingsViewModel`
- SwiftUI, Observation, and AppKit/`NSImage`
- RawCullCore and RawParserKit
- URLs, security-scoped access, and camera-vendor decoding
- cache directories, persistence, logging policy, and saved-file schemas
- sorting, rating, burst grouping, culling, and recommendation policy

The later RawCull integration should add a thin host adapter that decodes each
file, creates `PhotoAnalysisInput`, maps `SaliencySummary` to any culling-domain
summary, and preserves the existing observable progress/state model.
