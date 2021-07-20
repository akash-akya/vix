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
  def to_nif_term(str, _data) when is_binary(str) do
    if String.valid?(str) do
      [str, <<"\0">>]
    else
      raise ArgumentError, "value must be a valid UTF-8 string"
    end
  end

  @impl Type
  def to_erl_term(value), do: to_string(value)
end
