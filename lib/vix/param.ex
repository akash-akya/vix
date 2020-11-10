defmodule Vix.Param do
  alias Vix.Nif
  alias Vix.GObject.GParamSpec

  def vips_operation_arguments(name) do
    Nif.nif_vips_operation_get_arguments(name)
    |> Enum.map(fn {name, spec_details, priority, flags} ->
      {desc, spec_type, value_type, data} = spec_details

      %GParamSpec{
        param_name: List.to_atom(name),
        desc: desc,
        spec_type: to_string(spec_type),
        value_type: to_string(value_type),
        data: data,
        priority: priority,
        flags: flags
      }
    end)
    |> Enum.filter(fn %{flags: flags} -> :vips_argument_input in flags end)
    |> Map.new(fn %{param_name: name} = param -> {name, param} end)
  end
end
