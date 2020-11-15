defmodule Vix.OperationHelper do
  @moduledoc false

  alias Vix.Nif
  alias Vix.Type
  alias Vix.GObject.GParamSpec

  def prepare_doc(desc, required, optional) do
    doc_required_args =
      Enum.map_join(required, "\n", fn pspec ->
        "  * #{pspec.param_name} - #{pspec.desc}"
      end)

    doc_optional_args =
      Enum.map_join(optional, "\n", fn pspec ->
        "  * #{pspec.param_name} - #{pspec.desc} (#{pspec.value_type})"
      end)

    """
    #{String.capitalize(to_string(desc))}

    ## Arguments
    #{doc_required_args}

    ## Optional
    #{doc_optional_args}
    """
  end

  def operation_args(name) do
    {desc, args} = vips_operation_arguments(name)

    {input, rest} =
      Enum.split_with(args, fn %{flags: flags} ->
        :vips_argument_input in flags
      end)

    {output, _rest} =
      Enum.split_with(rest, fn %{flags: flags} ->
        :vips_argument_output in flags
      end)

    {required, optional} =
      Enum.split_with(input, fn %{flags: flags} ->
        :vips_argument_required in flags
      end)

    required = Enum.sort_by(required, & &1.priority)
    {desc, required, optional, output}
  end

  def function_name(name), do: to_string(name) |> String.downcase() |> String.to_atom()

  def input_typespec(pspec_list) do
    Enum.map(pspec_list, fn pspec ->
      Type.typespec(pspec)
    end)
  end

  def output_typespec(pspec_list) do
    if length(pspec_list) == 1 do
      Type.typespec(hd(pspec_list))
    else
      quote do
        list(term())
      end
    end
  end

  def typespec(func_name, required, _optional, output) do
    quote do
      unquote(func_name)(unquote_splicing(input_typespec(required)), keyword()) ::
        unquote(output_typespec(output))
    end
  end

  defp vips_operation_arguments(name) do
    {description, args} = Nif.nif_vips_operation_get_arguments(name)

    args =
      Enum.map(args, fn {name, spec_details, priority, flags} ->
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

    {description, args}
  end
end

defmodule Vix.Operation do
  import Vix.OperationHelper

  alias Vix.Type
  alias Vix.Nif

  Nif.nif_vips_operation_list()
  |> Enum.uniq()
  |> Enum.map(fn name ->
    {desc, required, optional, output} = operation_args(name)

    func_name = function_name(name)
    func_args = Enum.map(required, &Macro.var(&1.param_name, __MODULE__))
    input_args = Map.new(required ++ optional, &{&1.param_name, &1})

    nif_args =
      Enum.map(required, fn pspec ->
        {Atom.to_charlist(pspec.param_name), Macro.var(pspec.param_name, __MODULE__)}
      end)

    @doc """
    #{prepare_doc(desc, required, optional)}
    """
    @spec unquote(typespec(func_name, required, optional, output))
    def unquote(func_name)(unquote_splicing(func_args), optional \\ []) do
      nif_optional_args =
        Enum.map(optional, fn {name, value} ->
          {Atom.to_charlist(name), value}
        end)

      nif_args =
        (unquote(nif_args) ++ nif_optional_args)
        |> Enum.map(fn {name, value} ->
          param_spec = Map.get(unquote(Macro.escape(input_args)), List.to_atom(name))
          {name, Type.new(value, param_spec)}
        end)

      result =
        Vix.Nif.nif_vips_operation_call(
          unquote(name),
          nif_args
        )

      if unquote(length(output)) == 1 do
        hd(result)
      else
        result
      end
    end
  end)
end
