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
  def cast(value, _data) do
    case value do
      value when is_boolean(value) ->
        value

      value ->
        raise ArgumentError,
              "value must be boolean. given: #{inspect(value)}"
    end
  end
end
