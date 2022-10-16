defmodule Vix.Vips.Interpolate do
  alias Vix.Type

  defstruct [:ref]

  alias __MODULE__

  @moduledoc """
  Make interpolators for operators like `affine` and `mapim`.
  """

  alias Vix.Nif
  alias Vix.Type

  @behaviour Type

  @typedoc """
  Represents an instance of VipsInterpolate
  """
  @type t() :: %Interpolate{ref: reference()}

  @impl Type
  def typespec do
    quote do
      unquote(__MODULE__).t()
    end
  end

  @impl Type
  def default(nil), do: :unsupported

  @impl Type
  def to_nif_term(interpolate, _data) do
    case interpolate do
      %Interpolate{ref: ref} ->
        ref

      value ->
        raise ArgumentError, message: "expected Vix.Vips.Interpolate. given: #{inspect(value)}"
    end
  end

  @impl Type
  def to_erl_term(ref), do: %Interpolate{ref: ref}

  @doc """
  Make a new interpolator by name.

  Make a new interpolator from the libvips class nickname. For example:

  ```elixir
  {:ok, interpolate} = Interpolate.new("bilindear")
  ```

  You can get a list of all supported interpolators from the command-line with:

  ```shell
  $ vips -l interpolate
  ```

  See for example `affine`.
  """
  @spec new(String.t()) :: {:ok, __MODULE__.t()} | {:error, term()}
  def new(name) do
    if String.valid?(name) do
      Nif.nif_interpolate_new(name)
      |> wrap_type()
    else
      {:error, "expected UTF-8 binary string"}
    end
  end

  @doc """
  Make a new interpolator by name.

  Make a new interpolator from the libvips class nickname. For example:

  ```elixir
  interpolate = Interpolate.new!("bilindear")
  ```

  You can get a list of all supported interpolators from the command-line with:

  ```shell
  $ vips -l interpolate
  ```

  See for example `affine`.
  """
  @spec new!(String.t()) :: __MODULE__.t()
  def new!(name) do
    case new(name) do
      {:ok, interpolate} ->
        interpolate

      {:error, error} ->
        raise error
    end
  end

  defp wrap_type({:ok, ref}), do: {:ok, %Interpolate{ref: ref}}
  defp wrap_type(value), do: value
end
