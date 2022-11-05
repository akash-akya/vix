defmodule Vix.Type do
  @moduledoc false

  alias Vix.GObject
  alias Vix.Vips

  @callback typespec() :: term()

  @callback default(term) :: term()

  @callback to_nif_term(term, term) :: term()

  @callback to_erl_term(term) :: term()

  def typespec(type) do
    impl(type).typespec()
  end

  def default(type, data) do
    impl(type).default(data)
  end

  def to_nif_term(type, value, data) do
    impl(type).to_nif_term(value, data)
  end

  def to_erl_term(type, value) do
    case impl(type) do
      :unsupported -> value
      module -> module.to_erl_term(value)
    end
  end

  def supported?(type), do: impl(type) != :unsupported

  # TODO:
  # we check if enum_type is enum or not just by the name
  # convert type in nif itself, see `get_enum_as_atom`
  defp impl({:enum, enum_type}) do
    Module.concat(Vix.Vips.Enum, String.to_atom(enum_type))
  end

  # TODO: convert type in nif itself, see `get_flags_as_atoms`
  defp impl({:flags, flag_type}) do
    Module.concat(Vix.Vips.Flag, String.to_atom(flag_type))
  end

  defp impl("VipsArray" <> nested_type) when nested_type in ~w(Int Double Image) do
    Module.concat(Vix.Vips.Array, String.to_atom(nested_type))
  end

  defp impl({:vips_array, nested_type})
       when nested_type in ~w(Int Double Image Enum.VipsBlendMode) do
    Module.concat(Vix.Vips.Array, String.to_atom(nested_type))
  end

  defp impl({_spec_type, _value_type}), do: :unsupported

  defp impl("gint"), do: GObject.Int
  defp impl("guint64"), do: GObject.UInt64
  defp impl("gdouble"), do: GObject.Double
  defp impl("gboolean"), do: GObject.Boolean
  defp impl("gchararray"), do: GObject.String
  defp impl("VipsRefString"), do: Vips.RefString
  defp impl("VipsBlob"), do: Vips.Blob
  defp impl("MutableVipsImage"), do: Vips.MutableImage
  defp impl("VipsImage"), do: Vips.Image
  defp impl("VipsSource"), do: Vips.Source
  defp impl("VipsTarget"), do: Vips.Target
  defp impl("VipsInterpolate"), do: Vips.Interpolate
  defp impl(_type), do: :unsupported
end
