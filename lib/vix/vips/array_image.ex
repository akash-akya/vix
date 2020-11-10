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
  def new(_value, _data) do
    raise "VipsArrayImage is not implemented yet"
  end
end
