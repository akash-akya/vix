defmodule Vix.Param do
  alias Vix.Nif
  alias Vix.GObject.GParamSpec

  def cast(value, %GParamSpec{spec_type: "GParamBoxed", value_type: "VipsArrayInt"} = param) do
    Enum.map(
      value,
      &cast(&1, %GParamSpec{param | spec_type: "GParamInt", value_type: "gint", data: nil})
    )
    |> Vix.Nif.nif_int_array()
  end

  def cast(value, %GParamSpec{spec_type: "GParamBoxed", value_type: "VipsArrayDouble"} = param) do
    Enum.map(
      value,
      &cast(&1, %GParamSpec{param | spec_type: "GParamDouble", value_type: "double", data: nil})
    )
    |> Vix.Nif.nif_double_array()
  end

  def cast(value, param_spec) do
    GParamSpec.cast(value, param_spec)
  end

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

  # def sample_test do
  #   Nif.nif_vips_operation_list()
  #   |> Enum.take(10)
  #   |> Enum.map(fn {nickname, desc, op_usage} ->
  #     args = Nif.nif_vips_operation_get_arguments(nickname)
  #     {nickname, desc, op_usage, args}
  #   end)
  #   |> Enum.map(fn {nickname, _desc, _usage, args} ->
  #     IO.puts("#{nickname}")

  #     Enum.map(args, fn {name, _pspec, _flags} ->
  #       IO.puts("  #{name}")
  #     end)
  #   end)

  #   :ok
  # end

  # def find_op_arguments(name) do
  #   Nif.nif_vips_operation_get_arguments(name)
  #   |> Enum.filter(fn {_, _, flags} ->
  #     :vips_argument_input in flags
  #   end)
  #   |> Map.new(fn {name, pspec, _} ->
  #     {to_string(name), pspec}
  #   end)
  # end
end
