defmodule Vix.Vips.ArrayImage do
  alias Vix.Type

  @behaviour Type
  @opaque t() :: reference()

  @impl Type
  def spec_type, do: "GParamBoxed"

  @impl Type
  def value_type, do: "VipsArrayImage"

  @impl Type
  def typespec do
    quote do
      list(unquote(Vix.Vips.Image.typespec()))
    end
  end

  @impl Type
  def new(value, data) do
    value
    |> Enum.map(&Vix.Vips.Image.new(&1, data))
    |> Vix.Nif.nif_image_array()
  end
end
