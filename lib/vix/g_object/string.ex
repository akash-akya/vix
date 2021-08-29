defmodule Vix.GObject.String do
  alias Vix.Type
  @moduledoc false
  @behaviour Type

  @impl Type
  def typespec do
    quote do
      String.t()
    end
  end

  @impl Type
  def default(default), do: default

  @impl Type
  def to_nif_term(str, _data) do
    if String.valid?(str) do
      [str, <<"\0">>]
    else
      raise ArgumentError, message: "expected UTF-8 binary string"
    end
  end

  @impl Type
  def to_erl_term(value) do
    if String.valid?(value) do
      value
    else
      # TODO: remove after debugging
      raise ArgumentError, "value from NIF is not a valid UTF-8 string"
    end
  end
end
