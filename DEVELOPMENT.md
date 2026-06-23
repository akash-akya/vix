# Vix Development Guide

This guide covers the build modes, local testing commands, precompiled libvips
management, and release workflow for Vix.

## Table of Contents

- [Development Environment](#development-environment)
- [Compilation Modes](#compilation-modes)
- [Building libvips Locally](#building-libvips-locally)
- [Build System](#build-system)
- [Precompiled libvips](#precompiled-libvips)
- [Toolchains](#toolchains)
- [Testing and Quality](#testing-and-quality)
- [Release Process](#release-process)
- [Troubleshooting](#troubleshooting)

## Development Environment

### Prerequisites

- Elixir 1.12 or newer
- Erlang/OTP with development headers available to `elixir_make`
- A C compiler such as `gcc` or `clang`
- `make`
- `pkg-config`, when using a platform-provided libvips
- `curl`, `tar`, `meson`, and `ninja` when building libvips locally

CI currently exercises newer Elixir/OTP combinations, but the package minimum is
defined in `mix.exs`.

### Initial Setup

```bash
git clone https://github.com/akash-akya/vix.git
cd vix

mix deps.get
make all
mix test
```

Use `iex -S mix` after compilation to inspect the library manually.

## Compilation Modes

Vix supports three compilation modes through `VIX_COMPILATION_MODE`.

### `PRECOMPILED_NIF_AND_LIBVIPS`

This is the default mode.

Vix uses `cc_precompiler`/`elixir_make` to download a precompiled NIF from the
Vix GitHub release when one is available. The downloaded NIF package includes
the required precompiled libvips runtime files.

If a precompiled NIF is not available for the current target, the NIF is built
locally and the precompiled libvips package is used as the libvips provider.

```bash
unset VIX_COMPILATION_MODE
mix compile
```

### `PRECOMPILED_LIBVIPS`

Use this mode when you want to compile the NIF locally but use the libvips
tarball published by the `sharp-libvips` fork.

```bash
export VIX_COMPILATION_MODE=PRECOMPILED_LIBVIPS
mix compile
mix test
```

This mode is the main validation path after changing the precompiled libvips
release tag or the native link settings.

### `PLATFORM_PROVIDED_LIBVIPS`

Use this mode when libvips is provided by the host system or by a local prefix.
Vix resolves libvips with `pkg-config vips` and links against the C libvips
library reported by `pkg-config`.

```bash
# Use the system libvips installation.
export VIX_COMPILATION_MODE=PLATFORM_PROVIDED_LIBVIPS
mix test

# Use a specific libvips install prefix.
export VIX_COMPILATION_MODE=PLATFORM_PROVIDED_LIBVIPS
export VIX_LIBVIPS_PREFIX=/path/to/libvips/prefix
mix test
```

`VIX_LIBVIPS_PREFIX` must point to the libvips install prefix, for example the
same path passed to Meson with `--prefix`. The Makefile prepends
`$VIX_LIBVIPS_PREFIX/lib/pkgconfig` to `PKG_CONFIG_PATH` and verifies that
`pkg-config` resolves libvips from that prefix.

### Useful Environment Variables

- `VIX_COMPILATION_MODE` - one of `PRECOMPILED_NIF_AND_LIBVIPS`,
  `PRECOMPILED_LIBVIPS`, or `PLATFORM_PROVIDED_LIBVIPS`
- `VIX_LIBVIPS_PREFIX` - custom libvips install prefix for
  `PLATFORM_PROVIDED_LIBVIPS`
- `CC_PRECOMPILER_CURRENT_TARGET` - override the current target triplet for
  precompiler testing
- `ELIXIR_MAKE_CACHE_DIR` - cache directory used by `elixir_make` and
  `cc_precompiler`
- `PKG_CONFIG` - `pkg-config` executable to use
- `V=1` - verbose native compilation output when invoking `make`

## Building libvips Locally

For development against a specific upstream libvips without publishing a custom
precompiled tarball, use `scripts/build_libvips.sh`.

The script downloads an upstream libvips source archive, builds it with Meson,
and installs it into a private prefix. It intentionally builds a normal C
libvips installation for `PLATFORM_PROVIDED_LIBVIPS` mode.

```bash
# Build a tagged release into ./.libvips/vX.X.X.
./scripts/build_libvips.sh --ref vX.X.X
export VIX_LIBVIPS_PREFIX="$(pwd)/.libvips/vX.X.X"
export VIX_COMPILATION_MODE=PLATFORM_PROVIDED_LIBVIPS
mix test

# Build the current upstream development branch.
./scripts/build_libvips.sh --ref master
export VIX_LIBVIPS_PREFIX="$(pwd)/.libvips/master"
export VIX_COMPILATION_MODE=PLATFORM_PROVIDED_LIBVIPS
mix test

# Install into an explicit destination, replacing it if present.
./scripts/build_libvips.sh ./.libvips/custom --ref vX.X.X --overwrite
```

If `--ref` is omitted, the script resolves the latest upstream libvips release.

## Build System

### Core Commands

```bash
make all
make compile
mix compile

make clean
make clean_precompiled_libvips
make deep_clean

make debug
make V=1 all
```

`make debug` prints the effective native build configuration, including the
selected compilation mode, compiler flags, linker flags, and resolved libvips
version when `pkg-config` is used.

### Native Link Behavior

`PLATFORM_PROVIDED_LIBVIPS` uses:

```bash
pkg-config --cflags vips
pkg-config --libs vips
```

The precompiled modes use files extracted under `priv/precompiled_libvips`.
On POSIX platforms, current precompiled packages expose libvips through
`libvips-cpp`, and the Vix NIF links directly to:

```text
precompiled_libvips/lib/libvips-cpp.so.*
precompiled_libvips/lib/libvips-cpp.*.dylib
```

This is intentional. The `sharp-libvips` package builds `libvips-cpp` with the
libvips C ABI available from that shared object, so Vix does not need a separate
`libvips.so` or `libvips.dylib` in the precompiled POSIX package.

The Hex precompiler package includes only the runtime files listed in
`make_precompiler_priv_paths` in `mix.exs`.

## Precompiled libvips

Precompiled libvips tarballs are published by the
[`akash-akya/sharp-libvips`](https://github.com/akash-akya/sharp-libvips) fork.

Current Vix configuration:

- sharp-libvips release tag: `v8.18.3-rc1`
- upstream libvips version in that tag: `8.18.3`
- Vix config field: `@release_tag` in `build_scripts/precompiler.exs`
- asset pattern: `sharp-libvips-<platform>.tar.gz`
- download URL:
  `https://github.com/akash-akya/sharp-libvips/releases/download/<tag>/<asset>`

The release should contain a tarball and matching `.integrity` file for each
platform produced by the `sharp-libvips` matrix.

Vix currently maps these precompiled libvips targets:

- `x86_64-linux-gnu` -> `sharp-libvips-linux-x64.tar.gz`
- `x86_64-linux-musl` -> `sharp-libvips-linuxmusl-x64.tar.gz`
- `aarch64-linux-gnu` -> `sharp-libvips-linux-arm64v8.tar.gz`
- `aarch64-linux-musl` -> `sharp-libvips-linuxmusl-arm64v8.tar.gz`
- `arm-linux-gnueabihf` -> `sharp-libvips-linux-armv6.tar.gz`
- `armv7l-linux-gnueabihf` -> `sharp-libvips-linux-armv6.tar.gz`
- `x86_64-apple-darwin` -> `sharp-libvips-darwin-x64.tar.gz`
- `aarch64-apple-darwin` -> `sharp-libvips-darwin-arm64v8.tar.gz`

The `sharp-libvips` release may also publish Windows, wasm, and other Linux
architecture tarballs. Vix should only depend on targets present in
`build_scripts/precompiler.exs` and `mix.exs`.

## Toolchains

Vix uses musl cross-compilers when building precompiled NIFs for musl targets.
The upstream musl.cc host can be unreliable, so this repository mirrors the
required archives on GitHub releases.

### Download Toolchains

```bash
./scripts/download_toolchains.sh
```

The script downloads:

- `x86_64-linux-musl-cross.tgz`
- `aarch64-linux-musl-cross.tgz`

It tries the Vix GitHub release mirror first and then falls back to musl.cc.

### Mirror New Toolchains

```bash
./scripts/mirror_toolchains.sh
```

To update the mirror:

1. Run `./scripts/mirror_toolchains.sh`.
2. Create a GitHub release named `toolchains-v<version>`, for example
   `toolchains-v11.2.1`.
3. Upload the generated archives from `toolchains/`.
4. Update `TOOLCHAIN_VERSION` in `scripts/download_toolchains.sh` and
   `scripts/mirror_toolchains.sh` if the version changed.

## Testing and Quality

### Common Test Commands

```bash
# Default behavior.
mix test

# Force a local NIF build against precompiled libvips.
rm -rf _build/*/lib/vix cache/ priv/* checksum.exs
ELIXIR_MAKE_CACHE_DIR="$(pwd)/cache" \
VIX_COMPILATION_MODE=PRECOMPILED_LIBVIPS \
mix test

# Use a system or local-prefix libvips.
VIX_COMPILATION_MODE=PLATFORM_PROVIDED_LIBVIPS mix test

# Test one file.
mix test test/vix/vips/image_test.exs

# Coverage.
mix coveralls
```

### Code Quality

```bash
make format
mix format --check-formatted

make lint
mix credo

make dialyxir
mix dialyzer
```

### Before Committing

Run the checks that match the risk of the change. For native build or libvips
packaging changes, run at least:

```bash
git diff --check
mix format --check-formatted mix.exs

rm -rf _build/*/lib/vix cache/ priv/* checksum.exs
ELIXIR_MAKE_CACHE_DIR="$(pwd)/cache" \
VIX_COMPILATION_MODE=PRECOMPILED_LIBVIPS \
mix compile

ELIXIR_MAKE_CACHE_DIR="$(pwd)/cache" \
VIX_COMPILATION_MODE=PRECOMPILED_LIBVIPS \
mix test
```

Also test `PLATFORM_PROVIDED_LIBVIPS` when changes touch `c_src/Makefile`,
native link flags, GLib/libvips calls, or local libvips development support.

Generated paths such as `_build/`, `deps/`, `priv/`, `cache/`, `.libvips/`, and
`toolchains/` should not be committed.

## Release Process

### Standard Vix Release

Use this process for Vix package/NIF changes when the precompiled libvips tag is
not changing.

1. Update the package version in `mix.exs`.

   ```bash
   git add mix.exs
   git commit -m "Bump version to X.Y.Z"
   git push origin master
   ```

2. Create and push the release tag.

   ```bash
   git tag -a vX.Y.Z -m "Release vX.Y.Z"
   git push origin vX.Y.Z
   ```

3. Wait for `.github/workflows/precompile.yaml` to upload all NIF tarballs to
   the GitHub release.

4. Generate and commit checksums.

   ```bash
   rm -rf cache/ priv/* checksum.exs _build/*/lib/vix
   ELIXIR_MAKE_CACHE_DIR="$(pwd)/cache" \
   MIX_ENV=prod \
   mix elixir_make.checksum --all

   cat checksum.exs
   git add checksum.exs
   git commit -m "Update precompiled checksums"
   ```

5. Test the release artifacts and publish to Hex.

   ```bash
   rm -rf cache/ priv/* _build/*/lib/vix
   ELIXIR_MAKE_CACHE_DIR="$(pwd)/cache" mix test

   mix hex.publish
   ```

### Libvips Update Release

Use this process when Vix should consume a new precompiled libvips release from
the `sharp-libvips` fork.

#### 1. Update the sharp-libvips Fork

```bash
cd ~/repos/clang/sharp-libvips-2
git fetch upstream
git checkout main
git rebase upstream/main
```

Resolve conflicts toward upstream's current libvips build behavior. The fork
should preserve only the fork-specific behavior Vix needs:

- fork-local notice URLs
- the direct GitHub release asset upload flow
- `.integrity` files for each tarball
- any deliberately disabled upstream freshness gate

Do not reintroduce the old C-only libvips packaging changes. Current Vix
precompiled POSIX builds are expected to consume `libvips-cpp`.

After validating the fork:

```bash
git push --force-with-lease origin main
git tag -a v<libvips-version>-rc<N> -m "libvips <libvips-version> rc<N>"
git push origin v<libvips-version>-rc<N>
```

For example:

```bash
git tag -a v8.18.3-rc1 -m "libvips 8.18.3 rc1"
git push origin v8.18.3-rc1
```

The `sharp-libvips` CI creates the GitHub release automatically and uploads
`sharp-libvips-<platform>.tar.gz` plus matching `.integrity` files.

#### 2. Verify sharp-libvips Assets

Check that the tag workflow succeeded and that the release contains all assets
Vix needs.

```bash
curl -fsSL \
  https://api.github.com/repos/akash-akya/sharp-libvips/releases/tags/v8.18.3-rc1 \
  | jq -r '.assets[].name' \
  | sort
```

At minimum, Vix needs these tarballs and their `.integrity` files:

```text
sharp-libvips-darwin-arm64v8.tar.gz
sharp-libvips-darwin-x64.tar.gz
sharp-libvips-linux-arm64v8.tar.gz
sharp-libvips-linux-armv6.tar.gz
sharp-libvips-linux-x64.tar.gz
sharp-libvips-linuxmusl-arm64v8.tar.gz
sharp-libvips-linuxmusl-x64.tar.gz
```

#### 3. Update Vix

Update `@release_tag` in `build_scripts/precompiler.exs`.

```elixir
@release_tag "v8.18.3-rc1"
```

If the sharp-libvips package layout changed, also update:

- `c_src/Makefile` link inputs and rpath settings
- `make_precompiler_priv_paths` in `mix.exs`
- target mapping in `build_scripts/precompiler.exs`

#### 4. Test Vix Locally

```bash
cd ~/repos/elixir/vix

rm -rf _build/*/lib/vix cache/ priv/* checksum.exs

ELIXIR_MAKE_CACHE_DIR="$(pwd)/cache" \
VIX_COMPILATION_MODE=PRECOMPILED_LIBVIPS \
mix compile

ELIXIR_MAKE_CACHE_DIR="$(pwd)/cache" \
VIX_COMPILATION_MODE=PRECOMPILED_LIBVIPS \
mix test
```

Also verify `PLATFORM_PROVIDED_LIBVIPS` when native code or GLib/libvips calls
changed:

```bash
rm -rf _build/*/lib/vix priv/*
VIX_COMPILATION_MODE=PLATFORM_PROVIDED_LIBVIPS mix test
```

#### 5. Continue with the Standard Vix Release

After the Vix libvips configuration and tests are committed, follow the standard
Vix release process to build and publish Vix NIF artifacts.

## Troubleshooting

### `libvips not found`

For platform-provided builds, install libvips development headers or point Vix at
a local prefix.

```bash
# Debian/Ubuntu.
sudo apt-get install libvips-dev

# macOS.
brew install vips

# Custom prefix.
export VIX_COMPILATION_MODE=PLATFORM_PROVIDED_LIBVIPS
export VIX_LIBVIPS_PREFIX=/path/to/libvips/prefix
mix compile
```

Use `make debug` to inspect the effective `PKG_CONFIG_PATH`, C flags, and linker
flags.

### Precompiled libvips Download Fails

Check the configured tag and asset URL:

```bash
grep '@release_tag' build_scripts/precompiler.exs

curl -I \
  https://github.com/akash-akya/sharp-libvips/releases/download/v8.18.3-rc1/sharp-libvips-linux-x64.tar.gz
```

If Erlang reports a crypto or SSL error before downloading, fix the local
Erlang/OpenSSL installation. For example, an OTP build linked to
`libcrypto.so.1.1` will fail on a system where that shared library is missing.
That is an environment issue, not a sharp-libvips package issue.

As a local-only workaround for native compile testing, you can download and
extract the tarball with shell `curl`:

```bash
mkdir -p priv/precompiled_libvips
curl -fL -o priv/sharp-libvips-linux-x64.tar.gz \
  https://github.com/akash-akya/sharp-libvips/releases/download/v8.18.3-rc1/sharp-libvips-linux-x64.tar.gz
tar xzf priv/sharp-libvips-linux-x64.tar.gz -C priv/precompiled_libvips

ELIXIR_MAKE_CACHE_DIR="$(pwd)/cache" \
VIX_COMPILATION_MODE=PRECOMPILED_LIBVIPS \
mix compile
```

Do not treat this workaround as a substitute for testing the real downloader in
CI or in a healthy local OTP environment.

### `NIF compilation failed`

```bash
make deep_clean
make debug
make V=1 all
```

For precompiled libvips mode, confirm the expected library exists:

```bash
find priv/precompiled_libvips/lib -maxdepth 1 -name 'libvips-cpp*' -print
```

For platform-provided mode, confirm `pkg-config` can resolve libvips:

```bash
pkg-config --modversion vips
pkg-config --cflags --libs vips
```

### Checksum Verification Fails

Clear local cache and regenerate checksums against the intended release
artifacts.

```bash
rm -rf cache/ checksum.exs priv/* _build/*/lib/vix
ELIXIR_MAKE_CACHE_DIR="$(pwd)/cache" \
MIX_ENV=prod \
mix elixir_make.checksum --all
```

### Toolchain Download Fails

Check the mirror first:

```bash
curl -I \
  https://github.com/akash-akya/vix/releases/download/toolchains-v11.2.1/x86_64-linux-musl-cross.tgz
```

If the mirror is unavailable, manually download from musl.cc and extract into
the repository root:

```bash
wget https://more.musl.cc/11.2.1/x86_64-linux-musl/x86_64-linux-musl-cross.tgz
tar -xzf x86_64-linux-musl-cross.tgz
```

### Development Tips

- Use `ELIXIR_MAKE_CACHE_DIR="$(pwd)/cache"` to keep downloaded precompiled
  artifacts local to the repository.
- Use `PLATFORM_PROVIDED_LIBVIPS` for fast iteration against a system libvips.
- Use `VIX_LIBVIPS_PREFIX` when testing a specific local libvips build.
- Use `PRECOMPILED_LIBVIPS` before committing changes that affect the packaged
  libvips path.
- Use `make debug` and `make V=1 all` for native build diagnosis.
- Check GitHub Actions logs for platform-specific precompile failures.
