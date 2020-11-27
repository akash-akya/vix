defmodule Vix.Type do
  @moduledoc false

  alias Vix.{Vips, GObject}

  @callback typespec() :: term()

  @callback default(term) :: term()

  @callback cast(term, term) :: term()

  @callback to_erl_term(term) :: term()

  def typespec(pspec) do
    impl(pspec).typespec()
  end

  def default(pspec) do
    impl(pspec).default(pspec.data)
  end

  def cast(value, pspec) do
    impl(pspec).cast(value, pspec.data)
  end

  def to_erl_term(value, pspec) do
    impl(pspec).to_erl_term(value)
  end

  def supported?(pspec), do: impl(pspec) != :unsupported

  defp impl(pspec) do
    case {pspec.spec_type, pspec.value_type} do
      {"GParamBoxed", "VipsArrayInt"} ->
        Vips.ArrayInt

      {"GParamBoxed", "VipsArrayDouble"} ->
        Vips.ArrayDouble

      {"GParamBoxed", "VipsArrayImage"} ->
        Vips.ArrayImage

      {"GParamBoxed", "VipsBlob"} ->
        Vips.Blob

      {"GParamObject", "VipsImage"} ->
        Vips.Image

      {"GParamObject", "VipsSource"} ->
        Vips.Source

      {"GParamObject", "VipsTarget"} ->
        Vips.Target

      {"GParamEnum", enum_type} ->
        Module.concat(Vix.Vips.Enum, String.to_atom(enum_type))

      {"GParamFlags", flag_type} ->
        Module.concat(Vix.Vips.Flag, String.to_atom(flag_type))

      {_, "gint"} ->
        GObject.Int

      {_, "guint64"} ->
        GObject.UInt64

      {_, "gdouble"} ->
        GObject.Double

      {_, "gboolean"} ->
        GObject.Boolean

      {_, "gchararray"} ->
        GObject.String

      {_spec_type, _value_type} ->
        :unsupported
    end
  end
end
