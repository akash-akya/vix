defmodule Vix.Vips.OperationHelper do
  @moduledoc false

  alias Vix.Nif
  alias Vix.Type
  alias Vix.GObject.GParamSpec

  def prepare_doc(desc, required, optional) do
    doc_required_args =
      Enum.map_join(required, "\n", fn pspec ->
        "  * #{pspec.param_name} - #{pspec.desc}"
      end)

    """
    #{String.capitalize(to_string(desc))}

    ## Arguments
    #{doc_required_args}

    #{optional_args(optional)}
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

    # TODO: support VipsInterpolate and other types
    optional = Enum.filter(optional, &Type.supported?/1)

    required = Enum.sort_by(required, & &1.priority)
    {desc, required, optional, output}
  end

  def function_name(name), do: to_string(name) |> String.downcase() |> String.to_atom()

  def type_name(name) do
    to_string(name)
    |> Macro.underscore()
    |> String.to_atom()
    |> Macro.var(__MODULE__)
  end

  def input_typespec(pspec_list) do
    Enum.map(pspec_list, &typespec/1)
  end

  def output_typespec(pspec_list) do
    if length(pspec_list) == 1 do
      typespec(hd(pspec_list))
    else
      quote do
        list(term())
      end
    end
  end

  def typespec(func_name, required, optional, output) do
    quote do
      unquote(func_name)(
        unquote_splicing(input_typespec(required)),
        unquote(optional_args_typespec(optional))
      ) ::
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

  defp default(pspec) do
    if Type.default(pspec) == :unsupported do
      ""
    else
      "Default: `#{inspect(Type.default(pspec))}`"
    end
  end

  defp optional_args([]), do: ""

  defp optional_args(optional) do
    doc_optional_args =
      Enum.map_join(optional, "\n", fn pspec ->
        "* #{pspec.param_name} - #{pspec.desc}. #{default(pspec)}"
      end)

    """
    ## Optional
    #{doc_optional_args}
    """
  end

  defp typespec(%GParamSpec{spec_type: "GParamEnum"} = pspec) do
    type_name(pspec.value_type)
  end

  defp typespec(%GParamSpec{spec_type: "GParamFlags"} = pspec) do
    type_name(pspec.value_type)
  end

  defp typespec(pspec), do: Type.typespec(pspec)

  defp optional_args_typespec(optional) do
    Enum.map(optional, fn pspec ->
      {pspec.param_name, typespec(pspec)}
    end)
  end
end

defmodule Vix.Vips.Operation do
  @moduledoc """
  Vips Operations
  """

  import Vix.Vips.OperationHelper

  alias Vix.Type
  alias Vix.Nif

  Vix.Nif.nif_vips_enum_list()
  |> Enum.map(fn {name, enum} ->
    {enum_str_list, _} = Enum.unzip(enum)

    @type unquote(type_name(name)) ::
            unquote(Enum.reduce(enum_str_list, &{:|, [], [&1, &2]}))
  end)

  Vix.Nif.nif_vips_flag_list()
  |> Enum.map(fn {name, flag} ->
    {flag_str_list, _} = Enum.unzip(flag)

    @type unquote(type_name(name)) ::
            list(unquote(Enum.reduce(flag_str_list, &{:|, [], [&1, &2]})))
  end)

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
          {name, Type.cast(value, param_spec)}
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
