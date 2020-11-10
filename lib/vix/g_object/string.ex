defmodule Vix.GObject.String do
  alias Vix.Type

  @behaviour Type
  @opaque t() :: reference()

  @impl Type
  def spec_type, do: "GParamString"

  @impl Type
  def value_type, do: "gchararray"

  @impl Type
  def new(value, _data) do
    case value do
      value when is_binary(value) -> to_charlist(value)
      value when is_list(value) -> value
    end
  end
end
