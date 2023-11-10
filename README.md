# Vix

[![CI](https://github.com/akash-akya/vix/actions/workflows/ci.yaml/badge.svg)](https://github.com/akash-akya/vix/actions/workflows/ci.yaml)
[![Hex.pm](https://img.shields.io/hexpm/v/vix.svg)](https://hex.pm/packages/vix)
[![docs](https://img.shields.io/badge/docs-hexpm-blue.svg)](https://hexdocs.pm/vix/)

Vix is an Elixir extension for [libvips](https://libvips.github.io/libvips/) image processing library.

About libvips from its documentation:

> libvips is a [demand-driven, horizontally threaded](https://github.com/libvips/libvips/wiki/Why-is-libvips-quick) image processing library. Compared to similar libraries, [libvips runs quickly and uses little memory](https://github.com/libvips/libvips/wiki/Speed-and-memory-use).

## About Vix

Vix is a **NIF** based bindings library for libvips.

**Major Features:**

* Vix can take full advantage of libvips [optimizations](https://libvips.github.io/libvips/API/current/How-it-works.md.html), such as joining of operations in the pipeline, cache. Since Vix is native binding
* Experimental support for streaming. User can read or write images without keeping complete image in memory. See `Vix.Vips.Image.new_from_enum/1` and `Vix.Vips.Image.write_to_stream/2`
* Efficient interoperability (zero-copy) with other libraries such as Nx, eVision. See `Vix.Vips.Image.new_from_binary/5` and `Vix.Vips.Image.write_to_tensor/1`
* By default vix provides pre built NIF and libvips binaries for major platforms, so you don't have to worry about bringing the libvips dependencies and compiling NIF. Just add vix and you are good to go! See below for more details
* Ergonomic bindings with auto generated documentation for the operations using vips introspection. So they always match the libvips installed. If newer libvips update adds or modify operations, you don't have to wait for vix to be updated, bindings for the operations along with documentation will be available automatically

Check [vips operation documentation](https://hexdocs.pm/vix/Vix.Vips.Operation.html) for the list of available operations and spec.

### Pre-compiled NIF and libvips

Starting from v0.16.0 vix can use either pre-built binaries or platform provided binaries.

By default Vix provides pre-built NIF and libvips and use that for operation. This makes deployment and release of your application a simple. No need to install any compiler toolchain and dependencies to use Vix. Pre-built libvips supports reading SVG, PNG, TIFF, JPEG, WEBP, RAW, HEIF, GIF. If you find that the pre-built libvips is missing support for an image format then you can bring your own libvips by installing it manually and configure vix to use that instead. Vix makes sure to generate relevant functions and documentation based on the dependencies you bring. For example, if you install libvips with dzsave support, vix will generate dzsave bindings for you.

You can choose this using `VIX_COMPILATION_MODE` env variable. This variable must be set both during compilation and runtime. Possible values are:

* `PRECOMPILED_NIF_AND_LIBVIPS` (Default): Uses vix provided NIF and libvips. No need to install any additional dependencies. Big thanks to [sharp](https://github.com/lovell/sharp) library maintainers, pre-compiled libvips is based on: https://github.com/lovell/sharp-libvips/.

  Run this command below to generate the required `checksum.exs` file.

  ```sh
  MIX_ENV=dev mix elixir_make.checksum --all --ignore-unavailable
  ```

* `PLATFORM_PROVIDED_LIBVIPS`: Uses platform provided libvips and NIF will be compiled during compilation phase. You need to install required build tools to compile NIF. To build NIF you need these:

    - libvips with development headers
      * **macOS**: using brew `brew install libvips`
      * **Linux**: using deb `apt install libvips-dev`
      For more details see https://www.libvips.org/install.html
    - `pkg-config`
    - C compiler

#### Should I use Vix or [Image](https://github.com/kipcole9/image)?

Vix is focused on bridging beam and libvips, and tries to be close to libvips interface to support large set of use cases. Because of this doing some basic operation might feel unintuitive. [Image](https://github.com/kipcole9/image) an excellent library by [@kipcole9](https://github.com/kipcole9) builds on top of Vix and provides more elixir friendly wrapper functions for common operations along with many additional features such handling Exif, Math operators, and more. And all of this is accompanied by good documentation. So for most of the users, using `Vix` via `Image` might be better choice.

## Introduction

Easiest way to get started or to explore the operations is to run Introduction Livebook.

[![Run in Livebook](https://livebook.dev/badge/v1/blue.svg)](https://livebook.dev/run?url=https%3A%2F%2Fgithub.com%2Fakash-akya%2Fvix%2Fblob%2Fmaster%2Flivebooks%2Fintroduction.livemd)

```elixir
# print vips version
IO.puts("Version: " <> Vix.Vips.version())

# contains image read/write functions
alias Vix.Vips.Image

# reading image from a file. Note that image is not actually loaded to the memory at this point.
# img is `%Image{}` struct.
{:ok, img} = Image.new_from_file("~/Downloads/kitty.png")

# You can also load image from binary. This let us to work images without touching file system.
# It tires to guess image format from the binary and uses correct loader.

bin = File.read!("~/Downloads/kitty.png")
{:ok, %Image{} = img} = Image.new_from_buffer(bin)

# If you know image format beforehand then you can use appropriate function from
# `Vix.Vips.Operation`. For example to load png you can use `Vix.Vips.Operation.pngload_buffer/2`.

bin = File.read!("~/Downloads/kitty.png")
{:ok, {img, _flags}} = Vix.Vips.Operation.pngload_buffer(bin)

# writing `Image` to a file.
# Image type selected based on the image path extension. See documentation for more options
:ok = Image.write_to_file(img, "kitty.jpg[Q=90]")

# let's print image dimensions
IO.puts("Width: #{Image.width(img)}")
IO.puts("Height: #{Image.height(img)}")


# Operations

# contains image processing operations
alias Vix.Vips.Operation

# getting a rectangular region from the image (crop)
{:ok, extract_img} = Operation.extract_area(img, 100, 50, 200, 200)

# create image thumbnail
#
# This operation is significantly faster than normal resize
# due to several optimizations such as shrink-on-load.
# You can read more about it in the libvips docs: https://github.com/libvips/libvips/wiki/HOWTO----Image-shrinking
#
# Check Vix docs for more details about several optional parameters
width = 100
{:ok, thumb} = Operation.thumbnail("~/Downloads/dog.jpg", width)


# resize image to 400x600. `resize` function accepts scaling factor.
# Skip `vscale` if you want to preserve aspect ratio
hscale = 400 / Image.width(img)
vscale = 600 / Image.height(img)
{:ok, resized_img} = Operation.resize(img, hscale, vscale: vscale)

# flip image
{:ok, flipped_img} = Operation.flip(img, :VIPS_DIRECTION_HORIZONTAL)

# Gaussian blur
{:ok, blurred_img} = Operation.gaussblur(img, 5)

# convert image to a grayscale image
{:ok, bw_img} = Operation.colourspace(img, :VIPS_INTERPRETATION_B_W)

# adding gray border
{:ok, extended_img} =
  Operation.embed(img, 10, 10, Image.width(img) + 20, Image.height(img) + 20,
    extend: :VIPS_EXTEND_BACKGROUND,
    background: [128]
  )

# rotate image 90 degree clockwise
{:ok, rotated_img} = Operation.rot(img, :VIPS_ANGLE_D90)

# join two images horizontally
{:ok, main_img} = Image.new_from_file("~/Downloads/kitten.svg")
{:ok, joined_img} = Operation.join(img, main_img, :VIPS_DIRECTION_HORIZONTAL, expand: true)

# render text as image
# see https://libvips.github.io/libvips/API/current/libvips-create.html#vips-text for more details
{:ok, {text, _}} = Operation.text(~s(<b>Vix</b> is <span foreground="red">awesome!</span>), dpi: 300, rgba: true)
# add text to an image
{:ok, img_with_text} = Operation.composite2(img, text, :VIPS_BLEND_MODE_OVER, x: 50, y: 20)


## Creating GIF
black = Operation.black!(500, 500, bands: 3)

# create images with different grayscale
frames = Enum.map(1..255//10, fn n ->
  Operation.linear!(black, [1], [n/255,n/255,n/255])
end)

{:ok, joined_img} = Operation.arrayjoin(frames, across: 1)

# set frame delay metadata. See `Image.mutate` documentation for more details
{:ok, joined_img} =
  Image.mutate(joined_img, fn mut_img ->
    frame_delay = List.duplicate(100, length(frames))
    :ok = Vix.Vips.MutableImage.set(mut_img, "delay", :VipsArrayInt, frame_delay)
  end)

:ok = Operation.gifsave(joined_img, Path.expand("~/Downloads/bw.gif"), "page-height": 500)
```

The [libvips reference manual](https://libvips.github.io/libvips/API/current/) has more detailed documentation about the operations.

### Livebooks

* Livebook implementing picture language defined in [*Structural and Interpretation of Computer Programs*](https://mitpress.mit.edu/sites/default/files/sicp/index.html) section [2.2.4](https://mitpress.mit.edu/sites/default/files/sicp/full-text/book/book-Z-H-15.html#%_sec_2.2.4).

[![Run in Livebook](https://livebook.dev/badge/v1/blue.svg)](https://livebook.dev/run?url=https%3A%2F%2Fgithub.com%2Fakash-akya%2Fvix%2Fblob%2Fmaster%2Flivebooks%2Fpicture-language.livemd)

* Creating Rainbow. Quick introduction to complex number and operations, `mapim`, `buildlut`.

[![Run in Livebook](https://livebook.dev/badge/v1/blue.svg)](https://livebook.dev/run?url=https%3A%2F%2Fgithub.com%2Fakash-akya%2Fvix%2Fblob%2Fmaster%2Flivebooks%2Frainbow.livemd)

* Auto correct Document Rotation. Quick introduction to Fourier Transformation, Complex planes, and Arithmetic Operations.

[![Run in Livebook](https://livebook.dev/badge/v1/blue.svg)](https://livebook.dev/run?url=https%3A%2F%2Fgithub.com%2Fakash-akya%2Fvix%2Fblob%2Fmaster%2Flivebooks%2Fauto_correct_rotation.livemd)

### NIF Error Logging

Vix NIF code writes logs to stderr on certain errors. This is disabled by default. To enable logging set `VIX_LOG_ERROR` environment variable to `true`.


## Installation

```elixir
def deps do
  [
    {:vix, "~> x.x.x"}
  ]
end
```
