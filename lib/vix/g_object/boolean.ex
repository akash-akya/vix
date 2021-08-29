defmodule Vix.GObject.Boolean do
  alias Vix.Type
  @moduledoc false
  @behaviour Type

  @impl Type
  def typespec do
    quote do
      boolean()
    end
  end

  @impl Type
  def default(default), do: default

  @impl Type
  def to_nif_term(value, _data) do
    case value do
      value when is_boolean(value) ->
        value

      value ->
        raise ArgumentError, message: "expected boolean. given: #{inspect(value)}"
    end
  end

  @impl Type
  def to_erl_term(value), do: value
end
