defmodule Vix.Vips.RefString do
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
  def to_nif_term(str, _data) do
    if String.valid?(str) do
      Vix.Nif.nif_vips_ref_string([str, <<"\0">>])
    else
      raise ArgumentError, message: "expected UTF-8 binary string"
    end
  end

  @impl Type
  def to_erl_term(value) do
    {:ok, value} = Vix.Nif.nif_vips_ref_string_to_erl_binary(value)

    if String.valid?(value) do
      value
    else
      # TODO: remove after debugging
      raise ArgumentError, "value from NIF is not a valid UTF-8 string"
    end
  end
end
