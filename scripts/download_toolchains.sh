#!/bin/bash
set -e

# Download musl toolchains with mirror fallback
TOOLCHAIN_VERSION="11.2.1"
MIRROR_URL="https://github.com/akash-akya/vix/releases/download/toolchains-v${TOOLCHAIN_VERSION}"
FALLBACK_URL="https://more.musl.cc/${TOOLCHAIN_VERSION}/x86_64-linux-musl"

download_and_extract() {
    local filename=$1
    local mirror_url="${MIRROR_URL}/${filename}"
    local fallback_url="${FALLBACK_URL}/${filename}"

    echo "Downloading $filename..."

    # Try mirror first
    if curl -fL --connect-timeout 30 --max-time 300 "$mirror_url" | tar -xz; then
        echo "✓ Downloaded $filename from mirror"
        return 0
    fi

    echo "Mirror failed, trying fallback..."

    # Fallback to original source with retry
    if curl -s --retry 3 --connect-timeout 30 --max-time 300 "$fallback_url" | tar -xz; then
        echo "✓ Downloaded $filename from fallback"
        return 0
    fi

    echo "✗ Failed to download $filename from both mirror and fallback"
    return 1
}

echo "Setting up musl cross-compilation toolchains..."

# Download required toolchains
download_and_extract "x86_64-linux-musl-cross.tgz"
download_and_extract "aarch64-linux-musl-cross.tgz"

echo "✓ All toolchains downloaded successfully"
