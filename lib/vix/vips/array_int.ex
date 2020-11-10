defmodule Vix.Vips.ArrayInt do
  alias Vix.Type

  @behaviour Type
  @opaque t() :: reference()

  @impl Type
  def spec_type, do: "GParamBoxed"

  @impl Type
  def value_type, do: "VipsArrayInt"

  @impl Type
  def new(value, data) do
    value
    |> Enum.map(&Vix.GObject.Int.new(&1, data))
    |> Vix.Nif.nif_int_array()
  end
end
