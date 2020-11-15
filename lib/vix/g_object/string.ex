defmodule Vix.GObject.String do
  alias Vix.Type
  @moduledoc false
  @behaviour Type

  @impl Type
  def spec_type, do: "GParamString"

  @impl Type
  def value_type, do: "gchararray"

  @impl Type
  def typespec do
    quote do
      charlist()
    end
  end

  @impl Type
  def new(value, _data) do
    case value do
      value when is_binary(value) -> to_charlist(value)
      value when is_list(value) -> value
    end
  end
end
