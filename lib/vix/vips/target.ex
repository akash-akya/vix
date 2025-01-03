defmodule Vix.Vips.Target do
  @moduledoc false

  alias Vix.Type
  alias __MODULE__

  @behaviour Type

  @type t() :: %Target{ref: reference()}

  defstruct [:ref]

  @impl Type
  def typespec do
    quote do
      unquote(__MODULE__).t()
    end
  end

  @impl Type
  def default(nil), do: :unsupported

  @impl Type
  def to_nif_term(target, _data) do
    case target do
      %Target{ref: ref} ->
        ref

      value ->
        raise ArgumentError, message: "expected Vix.Vips.Source given: #{inspect(value)}"
    end
  end

  @impl Type
  def to_erl_term(ref), do: %Target{ref: ref}
end
