defmodule Eips.GParamSpec do
  alias Eips.Nif

  def cast(value, "GParamInt", "gint") do
    case value do
      v when is_integer(v) -> v
      _v -> raise ArgumentError, "value must be integer"
    end
  end

  def cast(value, "GParamDouble", "double") do
    case value do
      v when is_integer(v) -> v * 1.0
      v when is_float(v) -> v
      _v -> raise ArgumentError, "value must be integer or double"
    end
  end

  def cast(value, "GParamUInt64", "guint64") do
    case value do
      v when is_integer(v) and v >= 0 -> v
      _v -> raise ArgumentError, "value must be unsigned integer"
    end
  end

  def cast(value, "GParamBoolean", "gboolean") do
    case value do
      v when is_boolean(v) -> v
      _v -> raise ArgumentError, "value must be boolean"
    end
  end

  def cast(value, "GParamObject", "VipsImage") do
    # TODO: check if vips image
    value
  end

  def cast(value, "GParamEnum", _enum_class) do
    # TODO: validate value
    value
  end

  def spec_type_name(pspec) do
    Nif.nif_g_param_spec_type_name(pspec)
    |> to_string()
  end

  def spec_value_type_name(pspec) do
    Nif.nif_g_param_spec_value_type_name(pspec)
    |> to_string()
  end
end
