defmodule Vix.Vips.ArrayImage do
  alias Vix.Type
  @moduledoc false

  @behaviour Type
  @opaque t() :: reference()

  @impl Type
  def typespec do
    quote do
      list(unquote(Vix.Vips.Image.typespec()))
    end
  end

  @impl Type
  def default(nil), do: :unsupported

  @impl Type
  def cast(value, data) do
    value
    |> Enum.map(&Vix.Vips.Image.cast(&1, data))
    |> Vix.Nif.nif_image_array()
  end

  @impl Type
  def to_erl_term(value) do
    {:ok, list} = Vix.Nif.nif_vips_image_array_to_erl_list(value)
    list
  end
end
