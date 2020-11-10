defmodule Vix.Vips.Blob do
  alias Vix.Type

  @behaviour Type
  @opaque t() :: reference()

  @impl Type
  def spec_type, do: "GParamBoxed"

  @impl Type
  def value_type, do: "VipsBlob"

  @impl Type
  def new(_value, _data), do: raise("VipsBlob is not implemented yet")
end
