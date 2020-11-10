defmodule Vix.Type do
  alias Vix.GObject.GParamSpec
  alias Vix.{Vips, GObject}

  @callback spec_type() :: String.t()

  @callback value_type() :: String.t()

  @callback new(term, GParamSpec.t()) :: term()

  def value_type(pspec) do
    impl(pspec).value_type()
  end

  def spec_type(pspec) do
    impl(pspec).spec_type()
  end

  def typespec(pspec) do
    quote do
      unquote(impl(pspec)).t
    end
  end

  def new(value, pspec) do
    impl(pspec).new(value, pspec.data)
  end

  defp impl(pspec) do
    case {pspec.spec_type, pspec.value_type} do
      {_, "VipsArrayInt"} -> Vips.ArrayInt
      {_, "VipsArrayDouble"} -> Vips.ArrayDouble
      {_, "VipsArrayImage"} -> Vips.ArrayImage
      {"GParamBoxed", "VipsBlob"} -> Vips.Blob
      {"GParamObject", "VipsImage"} -> Vips.Image
      {"GParamObject", "VipsSource"} -> Vips.Source
      {"GParamObject", "VipsTarget"} -> Vips.Target
      {_, "gint"} -> GObject.Int
      {_, "guint64"} -> GObject.Int
      {_, "gdouble"} -> GObject.Double
      {_, "gboolean"} -> GObject.Boolean
      {_, "gchararray"} -> GObject.String
      {"GParamEnum", _} -> GObject.Enum
      {"GParamFlags", _} -> GObject.Flags
    end
  end
end
