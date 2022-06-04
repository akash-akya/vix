defmodule Vix.Type do
  @moduledoc false

  alias Vix.{Vips, GObject}

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

  defp impl(type) do
    case type do
      # TODO: we check if enum_type is enum or not just by the name
      {:enum, enum_type} ->
        # TODO: convert type in nif itself, see `get_enum_as_atom`
        Module.concat(Vix.Vips.Enum, String.to_atom(enum_type))

      {:flags, flag_type} ->
        # TODO: convert type in nif itself, see `get_flags_as_atoms`
        Module.concat(Vix.Vips.Flag, String.to_atom(flag_type))

      {:vips_array, nested_type} when nested_type in ~w(Int Double Image Enum.VipsBlendMode) ->
        Module.concat(Vix.Vips.Array, String.to_atom(nested_type))

      {_spec_type, _value_type} ->
        :unsupported

      "gint" ->
        GObject.Int

      "guint64" ->
        GObject.UInt64

      "gdouble" ->
        GObject.Double

      "gboolean" ->
        GObject.Boolean

      "gchararray" ->
        GObject.String

      "VipsRefString" ->
        Vips.RefString

      "VipsBlob" ->
        Vips.Blob

      "VipsImage" ->
        Vips.Image

      "VipsSource" ->
        Vips.Source

      "VipsTarget" ->
        Vips.Target

      "VipsInterpolate" ->
        Vips.Interpolate

      _type ->
        :unsupported
    end
  end
end
