# Vix

[![CI](https://github.com/akash-akya/vix/actions/workflows/ci.yaml/badge.svg)](https://github.com/akash-akya/vix/actions/workflows/ci.yaml)
[![Hex.pm](https://img.shields.io/hexpm/v/vix.svg)](https://hex.pm/packages/vix)
[![docs](https://img.shields.io/badge/docs-hexpm-blue.svg)](https://hexdocs.pm/vix/)


Blazing fast image processing for Elixir powered by [libvips](https://libvips.github.io/libvips/), the same engine that powers [sharp.js](https://github.com/lovell/sharp).

## Perfect For

- Building image processing APIs and services
- Generating thumbnails at scale
- Image manipulation in web applications
- Computer vision preprocessing
- Processing large scientific/satellite images

## Features

- **High Performance**: Uses libvips' demand-driven, horizontally threaded architecture
- **Memory Efficient**: Processes images in chunks, perfect for large files
- **Streaming Support**: Read/write images without loading them fully into memory
- **Rich Ecosystem**: Zero-copy integration with [Nx](https://hex.pm/packages/nx) and [eVision](https://hex.pm/packages/evision)
- **Zero Setup**: Pre-built binaries for MacOS and Linux platforms included.
- **Auto-updating API**: New libvips features automatically available
- **Comprehensive Documentation**: [Type specifications and documentation](https://hexdocs.pm/vix/Vix.Vips.Operation.html) for 300+ operations

## Quick Start

```elixir
Mix.install([
  {:vix, "~> 0.23"}
])

alias Vix.Vips.{Image, Operation}

# Create a thumbnail and optimize for web
{:ok, thumb} = Operation.thumbnail("profile.jpg", 300)
:ok = Image.write_to_file(thumb, "thumbnail.jpg", Q: 90, strip: true, interlace: true)
```

[👉 Try in Livebook](https://livebook.dev/run?url=https%3A%2F%2Fgithub.com%2Fakash-akya%2Fvix%2Fblob%2Fmaster%2Flivebooks%2Fintroduction.livemd)

<!-- add before & after -->

## Common Operations

### Basic Processing
```elixir
# Reading an image
{:ok, img} = Image.new_from_file("profile.jpg")

# Resize preserving aspect ratio
{:ok, resized} = Operation.resize(img, 0.5)  # 50% of original size

# Crop a section
{:ok, cropped} = Operation.crop(img, 100, 100, 500, 500)

# Rotate with white background
{:ok, rotated} = Operation.rotate(img, 90, background: [255, 255, 255])

# Smart thumbnail (preserves important features)
{:ok, thumb} = Operation.thumbnail("large.jpg", 300, size: :VIPS_SIZE_DOWN, crop: :VIPS_INTERESTING_ATTENTION)
```

### Web Optimization
```elixir
# Convert to WebP with quality optimization
:ok = Image.write_to_file(img, "output.webp", Q: 80, effort: 4)

# Create progressive JPEG with metadata stripped
:ok = Image.write_to_file(img, "output.jpg", interlace: true, strip: true, Q: 85)

# Generate multiple formats
:ok = Image.write_to_file(img, "photo.avif", Q: 60)
:ok = Image.write_to_file(img, "photo.webp", Q: 80)
:ok = Image.write_to_file(img, "photo.jpg", Q: 85)
```

### Filters & Effects
```elixir
# Blur
{:ok, blurred} = Operation.gaussblur(img, 3.0)

# Sharpen
{:ok, sharp} = Operation.sharpen(img, sigma: 1.0)

# Grayscale
{:ok, bw} = Operation.colourspace(img, :VIPS_INTERPRETATION_B_W)
```

### Advanced Usage
```elixir
# Smart thumbnail preserving important features
{:ok, thumb} = Operation.thumbnail(
  "large.jpg",
  300,
  size: :VIPS_SIZE_DOWN, # only downsize, it will just copy if asked to upsize
  crop: :VIPS_INTERESTING_ATTENTION
)

# Process image stream on the fly
{:ok, image} =
  File.stream!("large_photo.jpg", [], 65_536)
  |> Image.new_from_enum()
# use `image` for further operations...

# Stream image to S3
:ok =
  Image.write_to_stream(image, ".png")
  |> Stream.each(&upload_chunk_to_s3/1)
  |> Stream.run()
```

<!-- TODO: Would be great to add examples for: -->
<!-- - Watermarking -->
<!-- - Image composition -->
<!-- - Batch processing -->
<!-- - Text overlay -->

## Performance

Libvips very fast and uses very little memory. See the detailed [benchmark](https://github.com/libvips/libvips/wiki/Speed-and-memory-use). Resizing an image is typically 4x-5x faster than using the quickest ImageMagick settings. It can also work with very large images without completely loading them to the memory.

## Installation

Add Vix to your dependencies:

```elixir
def deps do
  [
    {:vix, "~> x.x.x"}
  ]
end
```

That's it! Vix includes pre-built binaries for MacOS & Linux.

## Advanced Setup

Want to use your system's libvips? Set before compilation:

```bash
export VIX_COMPILATION_MODE=PLATFORM_PROVIDED_LIBVIPS
```

See [libvips installation guide](https://www.libvips.org/install.html) for more details.


## Documentation & Resources

- [Complete API Documentation](https://hexdocs.pm/vix/)
- [Interactive Introduction (Livebook)](https://livebook.dev/run?url=https%3A%2F%2Fgithub.com%2Fakash-akya%2Fvix%2Fblob%2Fmaster%2Flivebooks%2Fintroduction.livemd)
- [Creating Rainbow Effects (Livebook)](https://livebook.dev/run?url=https%3A%2F%2Fgithub.com%2Fakash-akya%2Fvix%2Fblob%2Fmaster%2Flivebooks%2Frainbow.livemd)
- [Auto Document Rotation (Livebook)](https://livebook.dev/run?url=https%3A%2F%2Fgithub.com%2Fakash-akya%2Fvix%2Fblob%2Fmaster%2Flivebooks%2Fauto_correct_rotation.livemd)
- [Picture Language from SICP (Livebook)](https://livebook.dev/run?url=https%3A%2F%2Fgithub.com%2Fakash-akya%2Fvix%2Fblob%2Fmaster%2Flivebooks%2Fpicture-language.livemd)

## FAQ

### Should I use Vix or Image?

[Image](https://github.com/kipcole9/image) is a library which builds on top of Vix.

- Use [Image](https://github.com/kipcole9/image) when you need:
  - A more Elixir-friendly API for common operations
  - Higher-level operations like Blurhash
  - Simple, chainable functions for common operations

- Use Vix directly when you need:
  - Advanced VIPS features and fine-grained control
  - Complex image processing pipelines
  - Direct libvips performance and capabilities
  - Lesser dependencies

### What image formats are supported?
Out of the box: JPEG, PNG, WEBP, TIFF, SVG, HEIF, GIF, and more. Need others? Just install libvips with the required libraries!

## License

MIT License - see [LICENSE](LICENSE) for details.
