defmodule Vix.Vips.Target do
  alias Vix.Type

  @behaviour Type
  @opaque t() :: reference()

  @impl Type
  def spec_type, do: "GParamObject"

  @impl Type
  def value_type, do: "VipsTarget"

  @impl Type
  def new(_value, _data), do: raise("VipsTarget is not implemented yet")
end
