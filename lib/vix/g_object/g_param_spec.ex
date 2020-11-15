defmodule Vix.GObject.GParamSpec do
  @moduledoc false
  @type t :: %{}

  defstruct [:param_name, :desc, :spec_type, :value_type, :data, :priority, :flags]
end
