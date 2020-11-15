defmodule Vix.Vips.Blob do
  alias Vix.Type

  @behaviour Type
  @opaque t() :: reference()

  @impl Type
  def typespec do
    quote do
      unquote(__MODULE__).t()
    end
  end

  @impl Type
  def cast(_value, _data), do: raise("VipsBlob is not implemented yet")
end
