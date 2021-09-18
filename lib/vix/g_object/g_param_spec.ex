defmodule Vix.GObject.GParamSpec do
  @moduledoc false
  @type t :: %{}

  defstruct [:param_name, :desc, :spec_type, :value_type, :data, :priority, :flags]

  def type(%__MODULE__{spec_type: "GParamEnum", value_type: value_type}), do: {:enum, value_type}

  def type(%__MODULE__{spec_type: "GParamFlags", value_type: value_type}),
    do: {:flags, value_type}

  def type(%__MODULE__{value_type: value_type}), do: value_type
end
