defmodule Vix.GObject.Double do
  alias Vix.Type
  @moduledoc false

  @behaviour Type
  @opaque t() :: reference()

  @impl Type
  def spec_type, do: "GParamDouble"

  @impl Type
  def value_type, do: "double"

  @impl Type
  def typespec do
    quote do
      float()
    end
  end

  @impl Type
  def new(value, data) do
    case value do
      value when is_number(value) ->
        value =
          if !is_float(value) do
            value * 1.0
          else
            value
          end

        validate_number_limits!(value, data)
        value

      value ->
        raise ArgumentError,
              "value must be integer or double. given: #{inspect(value)}"
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
