# Vix [![Hex.pm](https://img.shields.io/hexpm/v/vix.svg)](https://hex.pm/packages/vix)

Vix is Elixir extension for [vips](https://libvips.github.io/libvips/) image processing library.

### Why Vix

Vix is a **NIF** based bindings library for libvips. Vix does not spawn OS processes for the operations like other libraries. And it can make full use of libvips [optimizations](https://libvips.github.io/libvips/API/current/How-it-works.md.html) such as joining of operations in the pipeline, cache etc.

Operation bindings are generated using vips introspection, so the generated documentation and bindings always matches the vips version installed.

Check [vips operation documentation](https://hexdocs.pm/vix/Vix.Vips.Operation.html) for the list of available operations and spec.

### What is Vips

*(from vips documentation)*

> libvips is a [demand-driven, horizontally threaded](https://github.com/libvips/libvips/wiki/Why-is-libvips-quick) image processing library. Compared to similar libraries, [libvips runs quickly and uses little memory](https://github.com/libvips/libvips/wiki/Speed-and-memory-use).

See [libvips documentation](https://libvips.github.io/libvips/API/current/How-it-works.md.html) for more details.


## Introduction

Easiest way to get started with Vix, or to explore the operations is to load [Introduction Notebook](./livebooks/intro.livemd) in [Livebook](https://github.com/livebook-dev/livebook).

### Available Notebooks:

* [Introduction](./livebooks/intro.livemd)
* [Picture Language](./livebooks/picture-language.livemd)

### Example

```elixir
# print vips version
IO.puts("Version: " <> Vix.Vips.version())

# contains image read/write functions
alias Vix.Vips.Image

# reading image from a file. Note that image is not actually loaded to the memory at this point.
# img is `%Image{}` struct.
{:ok, img} = Image.new_from_file("~/Downloads/kitty.png")

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

# create image thumbnail.
# this function accepts many optional parameters, see: https://libvips.github.io/libvips/API/current/Using-vipsthumbnail.md.html
# also see `Operation.thumbnail/3` which accepts image path
{:ok, thumb} = Operation.thumbnail_image(img, 100)

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
```

The [libvips reference manual](https://libvips.github.io/libvips/API/current/) has more detailed documentation about the operations.

### Warning

This library is experimental. Interface might change significantly in the future versions. The code is not well tested, so you might experience crashes.

### Requirements

* libvips
* pkg-config
* c compiler

## Installation

```elixir
def deps do
  [
    {:vix, "~> x.x.x"}
  ]
end
```

### TODO
- [ ] support mutable operations such as draw*
- [ ] support all remaining vips types
