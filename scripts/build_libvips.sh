#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: ./scripts/build_libvips.sh [destination] [--ref <ref>] [--overwrite]

Download, build, and install libvips from an upstream source archive into a
private prefix.

Arguments:
  [destination]       Install prefix for libvips.
                      Defaults to ./.libvips/<ref>.

Options:
  --ref <ref>         Build a specific Git ref such as a branch, tag, or
                      commit SHA. Defaults to the latest upstream tagged
                      release.
  --overwrite         Replace an existing destination after a successful staged
                      build.
  --help              Show this help.
EOF
}

die() {
  printf 'Error: %s\n' "$*" >&2
  exit 1
}

log() {
  printf '==> %s\n' "$*"
}

latest_ref() {
  local latest_url latest_tag

  latest_url=$(curl -fsSL --retry 3 --connect-timeout 30 \
    -o /dev/null -w '%{url_effective}' \
    https://github.com/libvips/libvips/releases/latest)

  latest_tag=${latest_url##*/}

  [ -n "$latest_tag" ] || die "Failed to resolve the latest libvips release"

  printf '%s\n' "$latest_tag"
}

workdir=
cleanup() {
  local status=$?

  if [ -n "${workdir:-}" ] && [ -d "$workdir" ]; then
    if [ "$status" -eq 0 ]; then
      rm -rf "$workdir"
    else
      printf 'Build failed. Temporary files were kept at %s\n' "$workdir" >&2
    fi
  fi
}
trap cleanup EXIT

destination=
ref=
overwrite=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --ref)
      [ "$#" -ge 2 ] || die "--ref requires a value"
      ref=$2
      shift 2
      ;;
    --overwrite)
      overwrite=1
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    --*)
      die "Unknown option: $1"
      ;;
    *)
      if [ -n "$destination" ]; then
        die "Only one destination may be provided"
      fi
      destination=$1
      shift
      ;;
  esac
done

if [ -z "$ref" ]; then
  log "Resolving latest libvips release"
  ref=$(latest_ref)
fi

[ -n "$ref" ] || die "libvips ref cannot be empty"

if [ -z "$destination" ]; then
  destination="./.libvips/$ref"
fi

if [ "$destination" = "/" ]; then
  die "Refusing to install into /"
fi

if [[ "$destination" = /* ]]; then
  destination_path=$destination
else
  destination_path="$PWD/$destination"
fi

if [ "$destination_path" != "/" ]; then
  destination_path=${destination_path%/}
fi

[ -e "$destination_path" ] && [ "$overwrite" -ne 1 ] &&
  die "Destination already exists: $destination_path (pass --overwrite to replace it)"

archive_name="libvips-${ref}.tar.gz"
archive_url="https://codeload.github.com/libvips/libvips/tar.gz/${ref}"

workdir=$(mktemp -d)
archive_path="$workdir/$archive_name"
source_root="$workdir/src"
source_path="$source_root/libvips"
build_path="$workdir/build"
stage_root="$workdir/stage"
staged_destination="$stage_root$destination_path"

mkdir -p "$source_root"
mkdir -p "$stage_root"

log "Downloading libvips ${ref}"
curl -fL --retry 3 --connect-timeout 30 --max-time 1800 \
  "$archive_url" -o "$archive_path"

log "Extracting source archive"
mkdir -p "$source_path"
tar -xf "$archive_path" -C "$source_path" --strip-components=1

log "Configuring Meson build"
meson setup "$build_path" "$source_path" \
  --prefix="$destination_path" \
  --libdir=lib \
  --buildtype=release \
  --default-library=shared \
  --backend=ninja \
  --wrap-mode=nofallback \
  -Dexamples=false \
  -Dcplusplus=false \
  -Ddocs=false \
  -Dcpp-docs=false \
  -Dintrospection=disabled \
  -Dvapi=false \
  -Dheif-module=disabled \
  -Djpeg-xl-module=disabled \
  -Dmagick-module=disabled \
  -Dopenslide-module=disabled \
  -Dpoppler-module=disabled

log "Compiling libvips"
meson compile -C "$build_path"

log "Installing into staged prefix"
DESTDIR="$stage_root" meson install -C "$build_path" --no-rebuild

[ -d "$staged_destination" ] ||
  die "Expected staged install directory not found: $staged_destination"

log "Publishing install prefix"
mkdir -p "$(dirname "$destination_path")"

if [ "$overwrite" -eq 1 ] && [ -e "$destination_path" ]; then
  rm -rf "$destination_path"
fi

mv "$staged_destination" "$destination_path"

log "libvips ${ref} installed to $destination_path"
cat <<EOF

Next steps:
  export VIX_LIBVIPS_PREFIX="$destination_path"
  export VIX_COMPILATION_MODE=PLATFORM_PROVIDED_LIBVIPS

Then compile or test Vix as usual:
  mix test
EOF
