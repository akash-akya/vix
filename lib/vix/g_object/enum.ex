defmodule Vix.GObject.Enum do
  alias Vix.Type

  @behaviour Type
  @opaque t() :: atom

  @impl Type
  def spec_type, do: "GParamEnum"

  @impl Type
  def value_type, do: raise("Error")

  @impl Type
  def typespec do
    quote do
      atom()
    end
  end

  @impl Type
  def new(value, data) do
    validate_enum!(value, data)
    value
  end

  defp validate_enum!(value, {enums, _}) do
    enum_names = Enum.map(enums, fn {name, _} -> name end)

    if value in enum_names do
      :ok
    else
      raise ArgumentError,
            "value must be one of #{inspect(enum_names)}. Given: #{inspect(value)}"
    end
  end
end
