defmodule Vix.Vips.Image do
  alias Vix.Type
  alias Vix.Nif

  @behaviour Type
  @opaque t() :: reference()

  @impl Type
  def spec_type, do: "GParamObject"

  @impl Type
  def value_type, do: "VipsImage"

  @impl Type
  def typespec do
    quote do
      unquote(__MODULE__).t()
    end
  end

  @impl Type
  def new(value, _data), do: value

  def new_from_file(path) do
    Nif.nif_image_new_from_file(normalize_string(path))
  end

  def write_to_file(vips_image, path) do
    Nif.nif_image_write_to_file(vips_image, normalize_string(path))
  end

  defp normalize_string(str) when is_binary(str), do: to_charlist(str)

  defp normalize_string(str) when is_list(str), do: str
end
