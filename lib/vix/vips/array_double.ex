defmodule Vix.Vips.ArrayDouble do
  alias Vix.Type

  @behaviour Type
  @opaque t() :: reference()

  @impl Type
  def spec_type, do: "GParamBoxed"

  @impl Type
  def value_type, do: "VipsArrayDouble"

  @impl Type
  def typespec do
    quote do
      list(float())
    end
  end

  @impl Type
  def new(value, data) do
    value
    |> Enum.map(&Vix.GObject.Double.new(&1, data))
    |> Vix.Nif.nif_int_array()
  end
end
