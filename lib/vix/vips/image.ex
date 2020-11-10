defmodule Vix.Vips.Image do
  alias Vix.Type

  @behaviour Type
  @opaque t() :: reference()

  @impl Type
  def spec_type, do: "GParamObject"

  @impl Type
  def value_type, do: "VipsImage"

  @impl Type
  def new(value, _data), do: value
end
