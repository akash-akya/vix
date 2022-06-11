defmodule Vix.Tensor do
  @moduledoc false

  alias Vix.Vips.Image

  defstruct data: nil,
            shape: {0, 0, 0},
            names: [:width, :height, :bands],
            type: {}

  def binary_to_tensor(binary, size, %Image{} = image)
      when is_binary(binary) and is_integer(size) do
    struct(__MODULE__,
      data: binary,
      shape: {Image.width(image), Image.height(image), Image.bands(image)},
      names: [:width, :height, :bands],
      type: nx_type(image)
    )
  end

  # should we support :VIPS_FORMAT_COMPLEX and :VIPS_FORMAT_DPCOMPLEX ?
  defp nx_type(image) do
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
