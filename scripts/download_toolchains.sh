#!/bin/bash
# Fetch the Bootlin musl cross toolchains used to precompile the musl NIFs.
#
# Archives are kept in toolchains/ (cached in CI, and uploaded as the mirror)
# and verified against the pinned SHA-256 on every run. The hashes match
# Buildroot's toolchain-external-bootlin.hash.
set -euo pipefail

VERSION="2026.08-1"
MIRROR_URL="https://github.com/akash-akya/vix/releases/download/toolchains-bootlin-${VERSION}"
BOOTLIN_URL="https://toolchains.bootlin.com/downloads/releases/toolchains"
ARCHIVE_DIR="toolchains"

# fetch <bootlin arch> <sha256> <output dir>
fetch() {
    local arch=$1 sha256=$2 dir=$3
    local file="${arch}--musl--stable-${VERSION}.tar.xz"
    local archive="${ARCHIVE_DIR}/${file}"

    if [ ! -f "$archive" ]; then
        echo "Downloading $file"
        curl -fsSL --proto '=https' --retry 3 -o "$archive.tmp" "${MIRROR_URL}/${file}" ||
            curl -fsSL --proto '=https' --retry 3 -o "$archive.tmp" "${BOOTLIN_URL}/${arch}/tarballs/${file}"
        mv "$archive.tmp" "$archive"
    fi

    if ! echo "${sha256}  ${archive}" | sha256sum -c --quiet -; then
        rm -f "$archive"
        exit 1
    fi

    rm -rf "$dir"
    mkdir -p "$dir"
    tar -xJf "$archive" -C "$dir" --strip-components=1
}

mkdir -p "$ARCHIVE_DIR"
fetch x86-64 78d3a4683d6ac47b5ee73bd5bce210b55eb93dff1b137c61298af97eb0d2b5a6 x86_64-linux-musl-cross
fetch aarch64 b388c480a48e8e9f9b99e3d14e69219c4d61e5a2424a82faecb88a015b781a60 aarch64-linux-musl-cross
