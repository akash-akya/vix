defmodule Vix.GObject.GParamSpec do
  alias Vix.Nif
  alias __MODULE__

  defstruct [:param_name, :spec_type, :value_type, :data, :priority, :flags]

  def cast(value, %__MODULE__{spec_type: "GParamInt", value_type: "gint"}) do
    case value do
      v when is_integer(v) -> v
      _v -> raise ArgumentError, "value must be integer"
    end
  end

  def cast(value, %__MODULE__{spec_type: "GParamDouble", value_type: "double"}) do
    case value do
      v when is_integer(v) -> v * 1.0
      v when is_float(v) -> v
      _v -> raise ArgumentError, "value must be integer or double"
    end
  end

  def cast(value, %__MODULE__{spec_type: "GParamUInt64", value_type: "guint64"}) do
    case value do
      v when is_integer(v) and v >= 0 -> v
      _v -> raise ArgumentError, "value must be unsigned integer"
    end
  end

  def cast(value, %__MODULE__{spec_type: "GParamBoolean", value_type: "gboolean"}) do
    case value do
      v when is_boolean(v) -> v
      _v -> raise ArgumentError, "value must be boolean"
    end
  end

  def cast(value, %__MODULE__{spec_type: "GParamObject", value_type: "VipsImage"}) do
    # TODO: check if vips image
    value
  end

  def cast(value, %__MODULE__{spec_type: "GParamEnum"}) do
    # TODO: validate value
    value
  end
end
