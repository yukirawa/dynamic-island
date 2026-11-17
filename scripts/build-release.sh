#!/usr/bin/env bash
# Build the two release flavours and pack each as a tarball under release/.
#   generic - portable x86-64, -O3 only
#   native  - -O3 -march=native -mtune=native, tuned for the build machine
set -euo pipefail

version="${1:-1.1.0}"
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
out="$root/release"
mkdir -p "$out"

build_variant() {
    local name="$1"
    shift
    local build_dir="$root/build-$name"
    local stage="$root/.release-stage-$name"

    echo "==> configuring $name"
    cmake -S "$root" -B "$build_dir" -G Ninja \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX="$HOME/.local" \
        "$@" >/dev/null
    echo "==> building $name"
    cmake --build "$build_dir" -j"$(nproc)"

    rm -rf "$stage"
    DESTDIR="$stage" cmake --install "$build_dir" >/dev/null
    local archive="$out/dynamic-island-$version-$name.tar.xz"
    tar -C "$stage" -cJf "$archive" .
    echo "==> $archive"
}

build_variant generic
build_variant native -DCMAKE_CXX_FLAGS_RELEASE="-O3 -march=native -mtune=native"

echo "==> checksums"
(cd "$out" && sha256sum dynamic-island-$version-*.tar.xz | tee "dynamic-island-$version-SHA256SUMS")
