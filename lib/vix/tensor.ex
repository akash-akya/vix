defmodule Vix.Tensor do
  alias Vix.Vips.Image

  @moduledoc """
  Struct to hold raw pixel data returned by the libvips along with metadata about the binary.

  Useful for interoperability between other libraries like [Nx](https://hexdocs.pm/nx/Nx.html), [Evision](https://github.com/cocoa-xu/evision/).

  See `Vix.Vips.Image.write_to_tensor/1` to convert an vix image to tensor.
  """

  @typedoc """
  Type of the image pixel when image is represented as Tensor.

  This type is useful for interoperability between different libraries. Type value is same as [`Nx.Type.t()`](https://hexdocs.pm/nx/Nx.Type.html)

  """

  @type tensor_type() ::
          {:u, 8}
          | {:s, 8}
          | {:u, 16}
          | {:s, 16}
          | {:u, 32}
          | {:s, 32}
          | {:f, 32}
          | {:f, 64}

  @typedoc """
  Struct to hold raw pixel data returned by the Libvips along with metadata about the binary.

  `:names` will always be `[:width, :height, :bands]`
  """

  @type t() :: %__MODULE__{
          data: binary(),
          shape: {non_neg_integer(), non_neg_integer(), non_neg_integer()},
          names: list(),
          type: tensor_type()
        }

  defstruct data: nil,
            shape: {0, 0, 0},
            names: [:width, :height, :bands],
            type: {}

  @doc """
  Convert Vix image pixel format to [Nx tensor type](https://hexdocs.pm/nx/Nx.Type.html#t:t/0)

  Vix internally uses [libvips image
  format](https://www.libvips.org/API/current/VipsImage.html#VipsBandFormat). To
  ease the interoperability between Vix and other elixir libraries, we
  can use this function.

  """
  @spec type(image :: Image.t()) :: tensor_type()
  def type(image) do
    # TODO: Function is too complex (cyclomatic complexity is 10, max is 9).
    # should we support :VIPS_FORMAT_COMPLEX and :VIPS_FORMAT_DPCOMPLEX ?
    case Image.format(image) do
      :VIPS_FORMAT_UCHAR ->
        {:u, 8}

      :VIPS_FORMAT_CHAR ->
        {:s, 8}

      :VIPS_FORMAT_USHORT ->
        {:u, 16}

      :VIPS_FORMAT_SHORT ->
        {:s, 16}

      :VIPS_FORMAT_UINT ->
        {:u, 32}

      :VIPS_FORMAT_INT ->
        {:s, 32}

      :VIPS_FORMAT_FLOAT ->
        {:f, 32}

      :VIPS_FORMAT_DOUBLE ->
        {:f, 64}

      other ->
        raise ArgumentError, "Cannot convert this image type to binary. Found #{inspect(other)}"
    end
  end
end
