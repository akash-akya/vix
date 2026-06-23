# Vix Development Guide

Repo-specific notes for native builds, precompiled libvips, CI, and releases.

## Compilation Modes

Vix supports three `VIX_COMPILATION_MODE` values:

- `PRECOMPILED_NIF_AND_LIBVIPS` is the default. It downloads a precompiled Vix
  NIF from the Vix GitHub release when one is available. Do not use this as the
  only check for native C changes, because it can reuse the released NIF instead
  of compiling local C sources.
- `PRECOMPILED_LIBVIPS` compiles the local NIF and links it against the
  sharp-libvips tarball. Use this for changes to native code, precompiled
  libvips, link flags, or packaged runtime files.
- `PLATFORM_PROVIDED_LIBVIPS` uses `pkg-config vips` and links against the host
  libvips. Set `VIX_LIBVIPS_PREFIX` to test a specific local libvips install.

Useful commands:

```bash
rm -rf _build/*/lib/vix cache/ priv/*

ELIXIR_MAKE_CACHE_DIR="$(pwd)/cache" \
VIX_COMPILATION_MODE=PRECOMPILED_LIBVIPS \
mix test

VIX_COMPILATION_MODE=PLATFORM_PROVIDED_LIBVIPS mix test

VIX_LIBVIPS_PREFIX=/path/to/libvips/prefix \
VIX_COMPILATION_MODE=PLATFORM_PROVIDED_LIBVIPS \
mix test

make debug
make V=1 all
```

Generated paths such as `_build/`, `deps/`, `priv/`, `cache/`, `.libvips/`,
`toolchains/`, and `checksum.exs` should not be committed.

## Precompiled libvips

Vix downloads precompiled libvips from
[`akash-akya/sharp-libvips`](https://github.com/akash-akya/sharp-libvips).

Current configuration:

- sharp-libvips release tag: `v8.18.3-rc1`
- upstream libvips version: `8.18.3`
- Vix config: `@release_tag` in `build_scripts/precompiler.exs`
- asset pattern: `sharp-libvips-<platform>.tar.gz`

Current target mapping:

| Vix target | sharp-libvips asset |
| --- | --- |
| `x86_64-linux-gnu` | `sharp-libvips-linux-x64.tar.gz` |
| `x86_64-linux-musl` | `sharp-libvips-linuxmusl-x64.tar.gz` |
| `aarch64-linux-gnu` | `sharp-libvips-linux-arm64v8.tar.gz` |
| `aarch64-linux-musl` | `sharp-libvips-linuxmusl-arm64v8.tar.gz` |
| `arm-linux-gnueabihf` | `sharp-libvips-linux-armv6.tar.gz` |
| `armv7l-linux-gnueabihf` | `sharp-libvips-linux-armv6.tar.gz` |
| `x86_64-apple-darwin` | `sharp-libvips-darwin-x64.tar.gz` |
| `aarch64-apple-darwin` | `sharp-libvips-darwin-arm64v8.tar.gz` |

For precompiled POSIX builds, Vix links directly to `libvips-cpp`:

```text
precompiled_libvips/lib/libvips-cpp.so.*
precompiled_libvips/lib/libvips-cpp.*.dylib
```

This is expected. The sharp-libvips package exports the libvips C ABI from
`libvips-cpp`, so the precompiled POSIX package does not need a separate
`libvips.so` or `libvips.dylib`.

The files copied into precompiled Vix NIF archives are controlled by
`make_precompiler_priv_paths` in `mix.exs`.

## Local libvips Builds

Use `scripts/build_libvips.sh` when testing Vix against an upstream libvips ref
without publishing a sharp-libvips release. The script builds a normal C
libvips install for `PLATFORM_PROVIDED_LIBVIPS`.

```bash
./scripts/build_libvips.sh --ref vX.Y.Z

VIX_LIBVIPS_PREFIX="$(pwd)/.libvips/vX.Y.Z" \
VIX_COMPILATION_MODE=PLATFORM_PROVIDED_LIBVIPS \
mix test
```

If `--ref` is omitted, the script resolves the latest upstream libvips release.
Use `--overwrite` to replace an existing local prefix.

## Toolchains

`precompile.yaml` uses musl cross-compilers for musl NIF targets. The scripts
mirror the required musl.cc archives on Vix GitHub releases:

```bash
./scripts/download_toolchains.sh
./scripts/mirror_toolchains.sh
```

The current mirrored version is `11.2.1`; update `TOOLCHAIN_VERSION` in both
scripts if the mirror changes.

## CI

`.github/workflows/ci.yaml` runs on pushes and pull requests to `master` and
`dev`. It covers:

- Linux `PLATFORM_PROVIDED_LIBVIPS` against the latest upstream libvips release.
- Linux `PRECOMPILED_LIBVIPS`.
- Linux default precompiled NIF mode with `mix elixir_make.checksum --only-local`.
- ARM precompiled smoke test through Docker/QEMU.
- macOS default precompiled and `PRECOMPILED_LIBVIPS` through Nix.
- compile with warnings as errors, unused dependency checks, formatter, Credo,
  and Dialyzer.

`.github/workflows/precompile.yaml` runs for `v*` tags and uploads
`cache/*.tar.gz` NIF artifacts to the matching GitHub release.

## Release Process

### Standard Vix Release

1. Bump `@version` in `mix.exs`, commit, and push `master`.

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

4. Generate checksums.

   ```bash
   unset VIX_COMPILATION_MODE
   rm -rf cache/ priv/* _build/*/lib/vix

   ELIXIR_MAKE_CACHE_DIR="$(pwd)/cache" \
   MIX_ENV=prod \
   mix elixir_make.checksum --all

   cat checksum.exs
   ```

   `checksum.exs` is generated, ignored by Git, and should not be committed.
   The checksum task rewrites it, so deleting an old copy first is optional.
   Keep it in the working tree for `mix hex.publish`.

5. Test the release artifacts, then publish.

   ```bash
   unset VIX_COMPILATION_MODE
   rm -rf cache/ priv/* _build/*/lib/vix

   ELIXIR_MAKE_CACHE_DIR="$(pwd)/cache" mix test
   mix hex.publish
   ```

   Before accepting the publish prompt, confirm the file list includes
   `checksum.exs` and `DEVELOPMENT.md`.

6. Optional cleanup:

   ```bash
   rm -rf cache/ priv/* checksum.exs _build/*/lib/vix doc/ vix-*.tar
   ```

   This is only housekeeping. `checksum.exs` can remain locally after publish.

### Failed Tag Build

If the tag workflow fails before Hex publish, fix `master`, push the fix, move
the tag, and force-push the tag:

```bash
git push origin master
git tag -fa vX.Y.Z -m "Release vX.Y.Z"
git push --force origin vX.Y.Z
```

The release workflow uses `overwrite_files: true`, so rerunning the same tag can
replace partial GitHub release artifacts. After a Hex package is public, do not
move the tag; publish a new patch or release-candidate version instead.

### Libvips Update

Use this when Vix should consume a new sharp-libvips release.

1. Rebase the sharp-libvips fork.

   ```bash
   cd ~/repos/clang/sharp-libvips-2
   git fetch upstream
   git checkout main
   git rebase upstream/main
   ```

   Preserve only the fork behavior Vix needs: direct GitHub release asset
   upload, `.integrity` files, fork-local notices, and any deliberate freshness
   gate change. Do not reintroduce old C-only packaging changes; Vix expects
   precompiled POSIX packages to provide `libvips-cpp`.

2. Push and tag the sharp-libvips release candidate.

   ```bash
   git push --force-with-lease origin main
   git tag -a v<libvips-version>-rc<N> -m "libvips <libvips-version> rc<N>"
   git push origin v<libvips-version>-rc<N>
   ```

3. Verify the release assets.

   ```bash
   curl -fsSL \
     https://api.github.com/repos/akash-akya/sharp-libvips/releases/tags/v8.18.3-rc1 \
     | jq -r '.assets[].name' \
     | sort
   ```

   Vix needs the mapped tarballs above and their `.integrity` files.

4. Update Vix.

   - Change `@release_tag` in `build_scripts/precompiler.exs`.
   - If the package layout changed, update `c_src/Makefile`,
     `make_precompiler_priv_paths` in `mix.exs`, and the target mapping in
     `build_scripts/precompiler.exs`.

5. Test locally.

   ```bash
   rm -rf _build/*/lib/vix cache/ priv/*

   ELIXIR_MAKE_CACHE_DIR="$(pwd)/cache" \
   VIX_COMPILATION_MODE=PRECOMPILED_LIBVIPS \
   mix test

   VIX_COMPILATION_MODE=PLATFORM_PROVIDED_LIBVIPS mix test
   ```

6. Follow the standard Vix release process.

## Troubleshooting

### Precompiled libvips Download Fails

Check the configured tag and asset URL:

```bash
grep '@release_tag' build_scripts/precompiler.exs

curl -I \
  https://github.com/akash-akya/sharp-libvips/releases/download/v8.18.3-rc1/sharp-libvips-linux-x64.tar.gz
```

If Erlang reports a crypto or SSL error before downloading, fix the local
Erlang/OpenSSL installation. For example, an OTP build linked to
`libcrypto.so.1.1` will fail where that shared library is missing.

### NIF Link Fails

```bash
make deep_clean
make debug
make V=1 all

find priv/precompiled_libvips/lib -maxdepth 1 -name 'libvips-cpp*' -print
pkg-config --modversion vips
pkg-config --cflags --libs vips
```

### Checksum Verification Fails

Regenerate checksums against the intended GitHub release artifacts:

```bash
rm -rf cache/ priv/* _build/*/lib/vix

ELIXIR_MAKE_CACHE_DIR="$(pwd)/cache" \
MIX_ENV=prod \
mix elixir_make.checksum --all
```
