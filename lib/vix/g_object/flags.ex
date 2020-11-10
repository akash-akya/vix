defmodule Vix.GObject.Flags do
  alias Vix.Type

  @behaviour Type
  @opaque t() :: list(atom)

  @impl Type
  def spec_type, do: "GParamFlags"

  @impl Type
  def value_type, do: raise("Error")

  @impl Type
  def typespec do
    quote do
      list(atom())
    end
  end

  @impl Type
  def new(value, data) do
    validate_flags!(value, data)
    value
  end

  defp validate_flags!(value, {flags, _}) do
    flag_names = Enum.map(flags, fn {name, _} -> name end)

    if value in flag_names do
      :ok
    else
      raise ArgumentError,
            "value must be in #{inspect(flag_names)}. Given: #{inspect(value)}"
    end
  end
end
