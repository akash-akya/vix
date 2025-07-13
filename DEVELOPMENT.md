# Vix Development Guide

This document provides comprehensive guidance for Vix development, testing, and release processes.

## Table of Contents

- [Development Environment Setup](#development-environment-setup)
- [Build System](#build-system)
- [Toolchain Management](#toolchain-management)
- [Testing and Quality Assurance](#testing-and-quality-assurance)
- [Release Process](#release-process)
- [Troubleshooting](#troubleshooting)

## Development Environment Setup

### Prerequisites

- Elixir 1.11+ with OTP 21+
- C compiler (gcc/clang)
- Make
- pkg-config (for system libvips detection)

### Compilation Modes

Vix supports three compilation modes controlled by the `VIX_COMPILATION_MODE` environment variable:

1. **`PRECOMPILED_NIF_AND_LIBVIPS`** (default) - Use precompiled NIFs and libvips
2. **`PRECOMPILED_LIBVIPS`** - Compile NIFs locally, use precompiled libvips
3. **`PLATFORM_PROVIDED_LIBVIPS`** - Use system-provided libvips

```bash
# Use system libvips (requires libvips-dev package)
export VIX_COMPILATION_MODE=PLATFORM_PROVIDED_LIBVIPS

# Force precompiled libvips build
export VIX_COMPILATION_MODE=PRECOMPILED_LIBVIPS
```

### Initial Setup

```bash
# Clone and build
git clone https://github.com/akash-akya/vix.git
cd vix
make all

# Run tests
mix test

# Verify installation
iex -S mix
```

## Build System

### Core Build Commands

```bash
# Build everything
make all
make compile

# Clean builds
make clean                          # Clean build artifacts
make deep_clean                     # Full clean including precompiled libvips
make clean_precompiled_libvips      # Remove only precompiled libvips

# Debug and verbose builds
make debug                          # Show build configuration (from c_src/)
make V=1 all                        # Verbose compilation output
```

### Build Configuration

Build behavior is controlled by several environment variables:

- `VIX_COMPILATION_MODE` - Compilation strategy
- `LIBVIPS_VERSION` - Override default libvips version
- `CC_PRECOMPILER_CURRENT_TARGET` - Override target platform
- `ELIXIR_MAKE_CACHE_DIR` - Cache directory for precompiled binaries

## Toolchain Management

### Musl Toolchain System

Vix uses musl toolchains for cross-compilation. Due to instability of the upstream musl.cc website, we maintain mirrors via GitHub releases.

#### Downloading Toolchains

```bash
# Download cached toolchains with fallback
./scripts/download_toolchains.sh
```

This script:
1. First attempts to download from our GitHub release mirror
2. Falls back to upstream musl.cc if mirror fails
3. Downloads and extracts `x86_64-linux-musl-cross.tgz` and `aarch64-linux-musl-cross.tgz`

#### Mirroring New Toolchains

```bash
# Mirror toolchains from upstream to local directory
./scripts/mirror_toolchains.sh
```

This creates a `toolchains/` directory with downloaded toolchain archives. To update the mirror:

1. Run the mirror script
2. Create a GitHub release tagged `toolchains-v{VERSION}` (e.g., `toolchains-v11.2.1`)
3. Upload the toolchain files as release assets
4. Update version in scripts if needed

### Precompiled libvips Management

Precompiled libvips binaries are managed through our [sharp-libvips fork](https://github.com/akash-akya/sharp-libvips).

Current configuration:
- **libvips version**: `8.15.3` (defined in `build_scripts/precompiler.exs:11`)
- **Release tag**: `8.15.3-rc3` (defined in `build_scripts/precompiler.exs:24`)

Supported platforms:
- Linux x64 (gnu/musl)
- Linux ARM64 (gnu/musl)  
- Linux ARMv7/ARMv6
- macOS x64/ARM64

## Testing and Quality Assurance

### Running Tests

```bash
# Standard test suite
mix test

# Test with cached precompiled binaries
ELIXIR_MAKE_CACHE_DIR="$(pwd)/cache" mix test

# Test specific files
mix test test/vix/vips/image_test.exs

# Coverage reports
mix coveralls
```

### Code Quality Tools

```bash
# Static analysis
make lint          # or mix credo
make dialyxir      # or mix dialyxir

# Code formatting
make format        # or mix format
```

### Pre-commit Checks

Before committing changes, ensure:

```bash
# Clean build passes
make clean && make all

# All tests pass
mix test

# Code quality checks pass
make lint && make dialyxir

# Code is formatted
make format
```

## Release Process

### Standard Release (NIF/Package Updates)

For releases without libvips changes:

1. **Prepare Release**
   ```bash
   # Bump version in mix.exs
   git add mix.exs
   git commit -m "Bump version to X.Y.Z"
   git push origin master
   ```

2. **Create GitHub Release**
   - Go to https://github.com/akash-akya/vix/releases
   - Create new release with tag `vX.Y.Z`
   - GitHub Actions automatically builds and uploads NIF artifacts
   - Wait for all artifacts to be available (check all BEAM NIF versions: 2.16, 2.17, etc.)

3. **Generate Checksums**
   ```bash
   # Clean local state
   rm -rf cache/ priv/* checksum.exs _build/*/lib/vix

   # Generate checksum file
   ELIXIR_MAKE_CACHE_DIR="$(pwd)/cache" MIX_ENV=prod mix elixir_make.checksum --all

   # Verify checksum contents
   cat checksum.exs
   ```

4. **Test and Publish**
   ```bash
   # Test precompiled packages
   ELIXIR_MAKE_CACHE_DIR="$(pwd)/cache" mix test

   # Publish to Hex
   mix hex.publish
   ```

### Libvips Update Release

For releases with new precompiled libvips versions:

1. **Update sharp-libvips Fork**
   ```bash
   cd ../sharp-libvips  # Your fork directory
   
   # Pull latest stable upstream changes
   git remote add upstream https://github.com/lovell/sharp-libvips.git
   git fetch upstream
   git checkout upstream/main
   
   # Apply our patches for shared library compatibility
   git cherry-pick <our-patch-commits>
   
   # Create tag matching upstream version
   git tag v8.15.X
   git push origin v8.15.X
   ```

2. **Wait for Artifacts**
   - GitHub Actions in sharp-libvips fork creates release and artifacts
   - Verify all required platform artifacts are created

3. **Update Vix Configuration**
   ```bash
   # Update build_scripts/precompiler.exs
   # - @vips_version (line 11)
   # - @release_tag (line 24)
   ```

4. **Test Locally**
   ```bash
   # Clean and test with new libvips
   rm -rf _build/*/lib/vix cache/ priv/* checksum.exs
   export VIX_COMPILATION_MODE=PRECOMPILED_LIBVIPS
   mix compile
   mix test
   ```

5. **Release**
   - Follow standard release process above
   - Push libvips configuration changes
   - Create Vix release and publish to Hex

## Troubleshooting

### Common Build Issues

**"libvips not found"**
```bash
# Install system libvips
sudo apt-get install libvips-dev  # Ubuntu/Debian
brew install vips                  # macOS

# Or force precompiled mode
export VIX_COMPILATION_MODE=PRECOMPILED_LIBVIPS
```

**"NIF compilation failed"**
```bash
# Clean and rebuild
make deep_clean
make all

# Check build configuration
cd c_src && make debug
```

**"Checksum verification failed"**
```bash
# Clear cache and regenerate
rm -rf cache/ checksum.exs
ELIXIR_MAKE_CACHE_DIR="$(pwd)/cache" MIX_ENV=prod mix elixir_make.checksum --all
```

### Toolchain Issues

**"Toolchain download failed"**
```bash
# Check if mirror is working
curl -I https://github.com/akash-akya/vix/releases/download/toolchains-v11.2.1/x86_64-linux-musl-cross.tgz

# Manually download and extract
wget https://more.musl.cc/11.2.1/x86_64-linux-musl/x86_64-linux-musl-cross.tgz
tar -xzf x86_64-linux-musl-cross.tgz
```

### Development Tips

- Use `ELIXIR_MAKE_CACHE_DIR="$(pwd)/cache"` to cache precompiled binaries locally
- Set `VIX_COMPILATION_MODE=PLATFORM_PROVIDED_LIBVIPS` for faster iteration during development
- Run `make debug` from `c_src/` directory to see detailed build configuration
- Use `mix test --trace` for verbose test output
- Check GitHub Actions logs for CI build failures
