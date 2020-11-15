defmodule Vix.Type do
  @moduledoc false

  alias Vix.{Vips, GObject}

  @callback typespec() :: term()

  @callback default(term) :: term()

  @callback cast(term, term) :: term()

  def typespec(pspec) do
    case impl(pspec) do
      err when is_binary(err) -> "typespec is not supported"
      impl -> impl.typespec()
    end
  end

  def default(pspec) do
    case impl(pspec) do
      err when is_binary(err) -> "default is not supported"
      impl -> impl.default(pspec.data)
    end
  end

  def cast(value, pspec) do
    case impl(pspec) do
      err when is_binary(err) -> "cast is not supported"
      impl -> impl.cast(value, pspec.data)
    end
  end

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

      {spec_type, value_type} ->
        "spec_type: #{spec_type} of value_type: #{value_type} is not supported"
    end
  end
end
