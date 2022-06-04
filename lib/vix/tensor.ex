defmodule Vix.Tensor do
  @moduledoc false

  alias Vix.Vips.Image

  defstruct [
    data: nil,
    shape: {0, 0, 0},
    names: [:width, :height, :bands],
    type: {}
  ]

  def binary_to_tensor(binary, size, %Image{} = image)
      when is_binary(binary) and is_integer(size) do
    struct(__MODULE__,
      data: binary,
      shape: {Image.width(image), Image.height(image), Image.bands(image)},
      names: [:width, :height, :bands],
      type: nx_type(image)
    )
  end

  # NOTE: This isn't really the right way to determine
  # the bit sizes of these types. Is there a way to get
  # this information from an existing NIF call, or do
  # we need a call to return format bit sizes?

  defp nx_type(image) do
    word_size = :erlang.system_info(:wordsize)

    case Image.format(image) do
      :VIPS_FORMAT_UCHAR   -> {:u, 8}
      :VIPS_FORMAT_CHAR    -> {:s, 8}
      :VIPS_FORMAT_USHORT  -> {:u, 16}
      :VIPS_FORMAT_SHORT   -> {:s, 16}
      :VIPS_FORMAT_UINT    -> {:u, word_size}
      :VIPS_FORMAT_INT     -> {:s, word_size}
      :VIPS_FORMAT_FLOAT   -> {:u, word_size}
      :VIPS_FORMAT_DOUBLE  -> {:u, word_size}
      other ->
        raise ArgumentError, "Cannot convert this image type to binary. Found #{inspect other}"
    end
  end

end