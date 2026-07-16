#!/bin/zsh

set -euo pipefail

package_root=${0:A:h:h}
resources="$package_root/Sources/PhotoAnalysisKit/Resources"
air_file="${TMPDIR:-/tmp}/PhotoAnalysisKit-Kernels.air"

xcrun metal \
    -fcikernel \
    -mmacosx-version-min=26.0 \
    -c "$resources/Kernels.ci.metal" \
    -o "$air_file"
xcrun metallib \
    --cikernel \
    "$air_file" \
    -o "$resources/default.metallib"

rm -f "$air_file"
