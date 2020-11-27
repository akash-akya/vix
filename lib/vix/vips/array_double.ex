defmodule Vix.Vips.ArrayDouble do
  alias Vix.Type
  @moduledoc false

  @behaviour Type
  @opaque t() :: reference()

  @impl Type
  def typespec do
    quote do
      list(float())
    end
  end

  @impl Type
  def default(nil), do: :unsupported

  @impl Type
  def cast(value, data) do
    value
    |> Enum.map(&Vix.GObject.Double.cast(&1, data))
    |> Vix.Nif.nif_double_array()
  end

  @impl Type
  def to_erl_term(value) do
    {:ok, list} = Vix.Nif.nif_vips_double_array_to_erl_list(value)
    list
  end
end
