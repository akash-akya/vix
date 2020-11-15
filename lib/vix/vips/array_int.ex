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
  def cast(value, data) do
    value
    |> Enum.map(&Vix.GObject.Int.cast(&1, data))
    |> Vix.Nif.nif_int_array()
  end
end
