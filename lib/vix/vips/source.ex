defmodule Vix.Vips.Source do
  alias Vix.Type

  @behaviour Type
  @opaque t() :: reference()

  @impl Type
  def spec_type, do: "GParamObject"

  @impl Type
  def value_type, do: "VipsSource"

  @impl Type
  def new(_value, _data), do: raise("VipsSource is not implemented yet")
end
