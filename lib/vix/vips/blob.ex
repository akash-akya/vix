defmodule Vix.Vips.Blob do
  alias Vix.Type
  @moduledoc false

  @behaviour Type
  @opaque t() :: reference()

  @impl Type
  def typespec do
    quote do
      binary()
    end
  end

  @impl Type
  def default(nil), do: :unsupported

  @impl Type
  def to_nif_term(value, _data) do
    Vix.Nif.nif_vips_blob(value)
  end

  @impl Type
  def to_erl_term(value) do
    {:ok, bin} = Vix.Nif.nif_vips_blob_to_erl_binary(value)
    bin
  end
end
