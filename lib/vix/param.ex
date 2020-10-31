defmodule Vix.Param do
  alias Vix.Nif
  alias Vix.GObject.GParamSpec

  def cast(value, "GParamBoxed", "VipsArrayInt") do
    Enum.map(value, &cast(&1, "GParamInt", "gint"))
    |> Vix.Nif.nif_int_array()
  end

  def cast(value, "GParamBoxed", "VipsArrayDouble") do
    Enum.map(value, &cast(&1, "GParamDouble", "double"))
    |> Vix.Nif.nif_double_array()
  end

  def cast(value, spec_type, value_type) do
    GParamSpec.cast(value, spec_type, value_type)
  end

  def cast(value, pspec) do
    cast(value, GParamSpec.spec_type_name(pspec), GParamSpec.spec_value_type_name(pspec))
  end

  defp filter_arguments(args, filter_flags) do
    Enum.filter(args, fn {_name, _pspec, _priority, flags} ->
      Enum.all?(filter_flags, &Enum.member?(flags, &1))
    end)
  end

  def vips_operation_arguments(name) do
    args =
      Nif.nif_vips_operation_get_arguments(name)
      |> filter_arguments([:vips_argument_input])

    {required, optional} =
      Enum.split_with(args, fn {_, _, _, flags} ->
        :vips_argument_required in flags
      end)

    required =
      Map.new(required, fn {name, pspec, priority, _} ->
        {List.to_atom(name),
         {priority, GParamSpec.spec_type_name(pspec), GParamSpec.spec_value_type_name(pspec)}}
      end)

    optional =
      Map.new(optional, fn {name, pspec, priority, _} ->
        {List.to_atom(name),
         {priority, GParamSpec.spec_type_name(pspec), GParamSpec.spec_value_type_name(pspec)}}
      end)

    {required, optional}
  end

  def sample_test do
    Nif.nif_vips_operation_list()
    |> Enum.take(10)
    |> Enum.map(fn {nickname, desc, op_usage} ->
      args = Nif.nif_vips_operation_get_arguments(nickname)
      {nickname, desc, op_usage, args}
    end)
    |> Enum.map(fn {nickname, _desc, _usage, args} ->
      IO.puts("#{nickname}")

      Enum.map(args, fn {name, _pspec, _flags} ->
        IO.puts("  #{name}")
      end)
    end)

    :ok
  end

  def find_op_arguments(name) do
    Nif.nif_vips_operation_get_arguments(name)
    |> Enum.filter(fn {_, _, flags} ->
      :vips_argument_input in flags
    end)
    |> Map.new(fn {name, pspec, _} ->
      {to_string(name), pspec}
    end)
  end
end
