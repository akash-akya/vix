defmodule Vix.GObject.UInt64 do
  alias Vix.Type
  @moduledoc false
  @behaviour Type

  @impl Type
  def typespec do
    quote do
      non_neg_integer()
    end
  end

  @impl Type
  def default({_min, _max, default}), do: default

  @impl Type
  def to_nif_term(value, data) do
    case value do
      value when is_integer(value) and value >= 0 ->
        validate_number_limits!(value, data)
        value

      value ->
        raise ArgumentError, message: "expected unsigned integer. given: #{inspect(value)}"
    end
  end

  @impl Type
  def to_erl_term(value), do: value

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
