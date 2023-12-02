# Release Notes

## Publishing new package without any changes to pre-built libvips package

* Bump version and push to master branch

* Create new release at: https://github.com/akash-akya/vix/releases
  Github Actions and TravisCI creates pre-compiled NIF artifacts and push to the release.
  Wait for all the release to be available. Ensure artifacts are created for all Beam
  NIF versions, like `2.16`, `2.17`

* Ensure all pre-built NIF packages are created

* On local machine, remove existing pre-built NIF packages, cache and checksum `rm -rf cache/ priv/* checksum.exs`

* Remove existing compiled files `rm -rf _build/*/lib/vix`

* Generate `checksum.exs` by running:
  `ELIXIR_MAKE_CACHE_DIR="$(pwd)/cache" MIX_ENV=prod mix elixir_make.checksum --all`
  This downloads all available artifacts and generates `checksum.exs` file based on it.
  Check checksum file contents

* Run test to ensure pre-built package pass the test `ELIXIR_MAKE_CACHE_DIR="$(pwd)/cache" mix test`

* Publish Hex package. `mix hex.publish`


## Publishing new package with pre-built libvips package changes

Pre-built libvips are built by our [fork](https://github.com/akash-akya/sharp-libvips)
with few changes to compile a shared library which works with C codebase.

* Pull latest **stable** [upstream](https://github.com/lovell/sharp-libvips/) changes

* Apply patches related to compile shared library compatible with C codebase from our repo

* Create a tag matching upstream and push. Ensure tag commit matches
  the upstream and not set on the latest master to avoid issues

* Once tag is pushed Github Actions creates a new release and creates artifacts

* Check if all required artifacts are created

* Update release_tag in the `precompiler.exs`

* Test locally by setting `export VIX_COMPILATION_MODE=PRECOMPILED_LIBVIPS`. You might
  have to delete old cache and build artifacts -- `rm -rf _build/*/lib/vix cache/ priv/* checksum.exs`

* Push changes to master and publish new release to Hex same as above
