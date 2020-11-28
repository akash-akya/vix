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
  def to_nif_term(value, _data) do
    case value do
      value when is_binary(value) -> to_charlist(value)
      value when is_list(value) -> value
    end
  end

  @impl Type
  def to_erl_term(value), do: to_string(value)
end
