defmodule Vix.GObject.GParamSpec do
  @type t :: %{}

  defstruct [:param_name, :desc, :spec_type, :value_type, :data, :priority, :flags]
end
