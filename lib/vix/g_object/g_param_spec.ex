defmodule Vix.GObject.GParamSpec do
  alias Vix.Nif
  alias __MODULE__

  defstruct [:param_name, :spec_type, :value_type, :data, :priority, :flags]

  def cast(value, %__MODULE__{spec_type: "GParamInt", value_type: "gint"} = param_spec) do
    case value do
      value when is_integer(value) ->
        validate_number_limits!(value, param_spec)
        value

      value ->
        raise ArgumentError,
              "#{param_spec.param_name} must be integer. given: #{inspect(value)}"
    end
  end

  def cast(value, %__MODULE__{spec_type: "GParamDouble", value_type: "double"} = param_spec) do
    case value do
      value when is_number(value) ->
        value =
          if is_float(value) do
            value * 1.0
          else
            value
          end

        validate_number_limits!(value, param_spec)
        value

      value ->
        raise ArgumentError,
              "#{param_spec.param_name} must be integer or double. given: #{inspect(value)}"
    end
  end

  def cast(value, %__MODULE__{spec_type: "GParamUInt64", value_type: "guint64"} = param_spec) do
    case value do
      value when is_integer(value) and value >= 0 ->
        validate_number_limits!(value, param_spec)
        value

      value ->
        raise ArgumentError,
              "#{param_spec.param_name} must be unsigned integer. given: #{inspect(value)}"
    end
  end

  def cast(value, %__MODULE__{spec_type: "GParamBoolean", value_type: "gboolean"} = param_spec) do
    case value do
      value when is_boolean(value) ->
        value

      value ->
        raise ArgumentError,
              "#{param_spec.param_name} must be boolean. given: #{inspect(value)}"
    end
  end

  def cast(value, %__MODULE__{spec_type: "GParamObject", value_type: "VipsImage"}) do
    # TODO: check if vips image
    value
  end

  def cast(value, %__MODULE__{spec_type: "GParamEnum"} = param_spec) do
    validate_enum!(value, param_spec)
    value
  end

  defp validate_number_limits!(value, %{data: nil}), do: :ok

  defp validate_number_limits!(value, %{data: {min, max, default}} = param_spec) do
    if max && value > max do
      raise ArgumentError, "#{param_spec.param_name} must be <= #{max}"
    end

    if min && value < min do
      raise ArgumentError, "#{param_spec.param_name} must be >= #{min}"
    end

    :ok
  end

  defp validate_enum!(value, %__MODULE__{data: {enums, _}} = param_spec) do
    enum_names = Enum.map(enums, fn {name, _} -> name end)

    if value in enum_names do
      :ok
    else
      raise ArgumentError,
            "#{param_spec.param_name} must be one of #{inspect(enum_names)}. Given: #{
              inspect(value)
            }"
    end
  end
end
