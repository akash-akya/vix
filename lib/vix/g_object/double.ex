defmodule Vix.GObject.Double do
  alias Vix.Type
  @moduledoc false
  @behaviour Type

  @impl Type
  def typespec do
    quote do
      float()
    end
  end

  @impl Type
  def default({_min, _max, default}), do: default

  @impl Type
  def to_nif_term(value, data) do
    case value do
      value when is_number(value) ->
        value = normalize(value)
        validate_number_limits!(value, data)
        value

      value ->
        raise ArgumentError, message: "expected integer or double. given: #{inspect(value)}"
    end
  end

  @impl Type
  def to_erl_term(value), do: value

  def normalize(num) when is_float(num), do: num
  def normalize(num) when is_integer(num), do: num * 1.0

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
