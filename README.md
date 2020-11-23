# Vix

Vix is Elixir extension for [vips](https://libvips.github.io/libvips/).

Vix is a **NIF bindings** for libvips. It uses dirty IO scheduler to avoid blocking VM. Operation binding are  auto generated using GObject introspection, so documentation and bindings are up-to-date with the vips version installed.

### What is Vips

*(from vips documentation)*

> libvips is a [demand-driven, horizontally threaded](https://github.com/libvips/libvips/wiki/Why-is-libvips-quick) image processing library. Compared to similar libraries, [libvips runs quickly and uses little memory](https://github.com/libvips/libvips/wiki/Speed-and-memory-use).

See [libvips documentation](https://libvips.github.io/libvips/API/current/How-it-works.md.html) for more details.

### Simple *unscientific* comparison

Generating thumbnail for a sample image

|   | Vix       | Mogrify   |
|---|-----------|-----------|
| 1 | 298.731ms | 618.854ms |
| 2 | 29.873ms  | 605.824ms |
| 3 | 34.479ms  | 609.820ms |
| 4 | 31.339ms  | 604.712ms |
| 5 | 32.526ms  | 605.553ms |

Notice that the gain is significant for the subsequent repetition of the operation for Vix since vips  [caches the operations](https://libvips.github.io/libvips/API/current/VipsOperation.html).

### Requirements

* libvips
* pkg-config

### Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `vix` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:vix, "~> x.x.x"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/vix](https://hexdocs.pm/vix).

### TODO
- [ ] support `VipsConnection`
- [ ] move GObject-introspection to a separate library
