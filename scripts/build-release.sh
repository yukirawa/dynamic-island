#!/usr/bin/env bash
# Build the two release flavours and output both standalone binaries and tarballs under release/:
#   generic - portable x86-64 (-O3 + LTO)
#   native  - -O3 -march=native -mtune=native + LTO, tuned for the build machine
set -euo pipefail

version="${1:-1.2.0}"
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
        -DCMAKE_INSTALL_PREFIX="/usr/local" \
        -DDYNAMIC_ISLAND_LTO=ON \
        "$@" >/dev/null
    echo "==> building $name"
    cmake --build "$build_dir" -j"$(nproc)"

    install -m 755 "$build_dir/dynamic-island" "$out/dynamic-island-$name"

    rm -rf "$stage"
    DESTDIR="$stage" cmake --install "$build_dir" >/dev/null
    local archive="$out/dynamic-island-$version-$name.tar.xz"
    tar -C "$stage" -cJf "$archive" .
    rm -rf "$stage"
    echo "==> $out/dynamic-island-$name"
    echo "==> $archive"
}

build_variant generic -DDYNAMIC_ISLAND_NATIVE=OFF
build_variant native -DDYNAMIC_ISLAND_NATIVE=ON

echo "==> checksums"
(
    cd "$out"
    sha256sum \
        "dynamic-island-generic" \
        "dynamic-island-native" \
        "dynamic-island-$version-generic.tar.xz" \
        "dynamic-island-$version-native.tar.xz" \
        > "dynamic-island-$version-SHA256SUMS"
    cp "dynamic-island-$version-SHA256SUMS" "SHA256SUMS"
    cat "SHA256SUMS"
)
