defmodule Vix.GObject.Boolean do
  alias Vix.Type

  @behaviour Type
  @opaque t() :: integer()

  @impl Type
  def spec_type, do: "GParamBoolean"

  @impl Type
  def value_type, do: "gboolean"

  @impl Type
  def new(value, _data) do
    case value do
      value when is_boolean(value) ->
        value

      value ->
        raise ArgumentError,
              "value must be boolean. given: #{inspect(value)}"
    end
  end
end
