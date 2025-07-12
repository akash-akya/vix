#!/bin/bash
set -e

# Mirror script for Vix musl toolchains
TOOLCHAIN_VERSION="11.2.1"
BASE_URL="https://more.musl.cc/${TOOLCHAIN_VERSION}/x86_64-linux-musl"
MIRROR_DIR="toolchains"

# Required toolchains
TOOLCHAINS=(
    "x86_64-linux-musl-cross.tgz"
    "aarch64-linux-musl-cross.tgz"
)

echo "Creating toolchain mirror directory..."
mkdir -p "$MIRROR_DIR"

echo "Downloading musl toolchains..."

for toolchain in "${TOOLCHAINS[@]}"; do
    echo "Downloading $toolchain..."
    url="${BASE_URL}/${toolchain}"
    output="${MIRROR_DIR}/${toolchain}"

    # Download with retry logic
    for attempt in {1..3}; do
        if curl -fL --connect-timeout 30 --max-time 600 "$url" -o "$output"; then
            echo "✓ Downloaded $toolchain successfully"
            # Verify the archive
            if tar -tzf "$output" >/dev/null 2>&1; then
                echo "✓ Verified $toolchain archive"
                break
            else
                echo "✗ Invalid archive for $toolchain, retrying..."
                rm -f "$output"
            fi
        else
            echo "✗ Failed to download $toolchain (attempt $attempt/3)"
            if [ $attempt -eq 3 ]; then
                echo "Failed to download $toolchain after 3 attempts"
                exit 1
            fi
            sleep 5
        fi
    done
done

echo ""
echo "Download complete! Files in $MIRROR_DIR:"
ls -lh "$MIRROR_DIR"

echo ""
echo "Next steps:"
echo "1. Create a GitHub release in your vix repository"
echo "2. Upload these files as release assets:"
echo "   - x86_64-linux-musl-cross.tgz"
echo "   - aarch64-linux-musl-cross.tgz"
echo "3. Update build scripts to use: https://github.com/akash-akya/vix/releases/download/toolchains-v${TOOLCHAIN_VERSION}/"
