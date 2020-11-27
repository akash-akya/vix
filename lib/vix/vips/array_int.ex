defmodule Vix.Vips.ArrayInt do
  alias Vix.Type
  @moduledoc false

  @behaviour Type
  @opaque t() :: reference()

  @impl Type
  def typespec do
    quote do
      list(integer())
    end
  end

  @impl Type
  def default(nil), do: :unsupported

  @impl Type
  def cast(value, data) do
    value
    |> Enum.map(&Vix.GObject.Int.cast(&1, data))
    |> Vix.Nif.nif_int_array()
  end

  @impl Type
  def to_erl_term(value) do
    {:ok, list} = Vix.Nif.nif_vips_int_array_to_erl_list(value)
    list
  end
end
