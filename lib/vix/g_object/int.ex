defmodule Vix.GObject.Int do
  alias Vix.Type

  @behaviour Type
  @opaque t() :: integer()

  @impl Type
  def spec_type, do: "GParamInt"

  @impl Type
  def value_type, do: "gint"

  @impl Type
  def new(value, data) do
    case value do
      value when is_integer(value) ->
        validate_number_limits!(value, data)
        value

      value ->
        raise ArgumentError,
              "value must be integer. given: #{inspect(value)}"
    end
  end

  defp validate_number_limits!(_value, nil), do: :ok

  defp validate_number_limits!(value, {min, max, _default}) do
    if max && value > max do
      raise ArgumentError, "value must be <= #{max}"
    end

    if min && value < min do
      raise ArgumentError, "value must be >= #{min}"
    end

    :ok
  end
end
