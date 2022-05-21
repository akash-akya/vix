defmodule Vix.Vips.OperationHelper do
  @moduledoc false

  alias Vix.Nif
  alias Vix.Type
  alias Vix.GObject.GParamSpec

  def input_to_nif_terms(args, in_pspec) do
    Enum.map(
      args,
      fn {name, value} ->
        pspec = Map.get(in_pspec, name)
        {name, Type.to_nif_term(pspec_type(pspec), value, pspec.data)}
      end
    )
  end

  def vips_enum_list do
    Nif.nif_vips_enum_list()
  end

  def vips_flag_list do
    Nif.nif_vips_flag_list()
  end

  def vips_operation_list do
    Nif.nif_vips_operation_list()
    |> Enum.uniq()
    |> Enum.reject(&reject_unsupported_operations/1)
  end

  def output_to_erl_terms(nif_out_args, required_out_pspec, optional_out_pspec) do
    {required, optional} =
      nif_out_args
      |> Enum.reduce({[], []}, fn {param, value}, {required, optional} ->
        cond do
          Map.has_key?(required_out_pspec, param) ->
            pspec = Map.get(required_out_pspec, param)
            value = Type.to_erl_term(pspec_type(pspec), value)
            {[{pspec.priority, value} | required], optional}

          Map.has_key?(optional_out_pspec, param) ->
            pspec = Map.get(optional_out_pspec, param)
            value = Type.to_erl_term(pspec_type(pspec), value)
            {required, [{String.to_atom(param), value} | optional]}

          true ->
            raise Vix.Vips.Operation.Error, message: "Invalid operation output field: #{param}"
        end
      end)

    required =
      required
      |> Enum.sort_by(fn {priority, _} -> priority end)
      |> Enum.map(fn {_, value} -> value end)

    case {required, optional} do
      {[], []} ->
        :ok

      # if it is single value then unwrap and return as single term
      {[term], []} ->
        {:ok, term}

      {required, optional} ->
        {:ok, List.to_tuple(required ++ [optional])}
    end
  end

  def prepare_doc(desc, required_in, optional_in, required_out, optional_out) do
    """
    #{String.capitalize(to_string(desc))}

    ## Arguments
    #{required_in_doc(required_in)}

    #{optional_in_doc(optional_in)}

    #{output_values_doc(required_out, optional_out)}
    """
  end

  def reject_unsupported_operations(op_name) do
    {_desc, args} = vips_operation_arguments(op_name)

    Enum.any?(args, fn %{flags: flags, value_type: value_type} ->
      # we do not support mutable operations & operations with VipsSource and VipsTarget as arguments
      :vips_argument_modify in flags ||
        value_type == "VipsSource" ||
        value_type == "VipsTarget"
    end)
  end

  def operation_args_spec(name) do
    {desc, args} = vips_operation_arguments(name)

    args =
      Enum.reject(args, fn %{flags: flags} ->
        # skip required deprecated arguments, but allow optional deprecated arguments.
        # This is similar to ruby-vips.
        :vips_argument_required in flags && :vips_argument_deprecated in flags
      end)

    {input, rest} =
      Enum.split_with(args, fn %{flags: flags} ->
        :vips_argument_input in flags
      end)

    {output, _rest} =
      Enum.split_with(rest, fn %{flags: flags} ->
        :vips_argument_output in flags
      end)

    {required_input, optional_input} =
      Enum.split_with(input, fn %{flags: flags} ->
        :vips_argument_required in flags
      end)

    {required_output, optional_output} =
      Enum.split_with(output, fn %{flags: flags} ->
        :vips_argument_required in flags
      end)

    optional_input =
      Enum.filter(optional_input, fn pspec ->
        Type.supported?(pspec_type(pspec))
      end)

    required_input = Enum.sort_by(required_input, & &1.priority)
    required_output = Enum.sort_by(required_output, & &1.priority)
    {desc, required_input, optional_input, required_output, optional_output}

    %{
      desc: desc,
      in_req_spec: required_input,
      in_opt_spec: optional_input,
      out_req_spec: required_output,
      out_opt_spec: optional_output
    }
  end

  def function_name(name), do: to_string(name) |> String.downcase() |> String.to_atom()

  def atom_typespec_ast(list) do
    Enum.reduce(list, &{:|, [], [&1, &2]})
  end

  def type_name(name) do
    to_string(name)
    |> Macro.underscore()
    |> String.to_atom()
    |> Macro.var(__MODULE__)
  end

  def output_typespec(required, optional) do
    case {required, optional} do
      {[], []} ->
        quote do
          :ok | {:error, term()}
        end

      {[pspec], []} ->
        quote do
          {:ok, unquote(typespec(pspec))} | {:error, term()}
        end

      {pspec_list, optional} ->
        optional_out = optional_args_typespec(optional)

        quote do
          {:ok, {unquote_splicing(typespec(pspec_list)), unquote(optional_out)}}
          | {:error, term()}
        end
    end
  end

  def bang_output_typespec(required, optional) do
    case {required, optional} do
      {[], []} ->
        quote do
          :ok | no_return()
        end

      {[pspec], []} ->
        quote do
          unquote(typespec(pspec)) | no_return()
        end

      {pspec_list, optional} ->
        optional_out = optional_args_typespec(optional)

        quote do
          {unquote_splicing(typespec(pspec_list)), unquote(optional_out)} | no_return()
        end
    end
  end

  def func_typespec(func_name, required_in, optional_in, required_out, optional_out) do
    quote do
      unquote(func_name)(
        unquote_splicing(typespec(required_in)),
        unquote(optional_args_typespec(optional_in))
      ) ::
        unquote(output_typespec(required_out, optional_out))
    end
  end

  def bang_func_typespec(func_name, required_in, optional_in, required_out, optional_out) do
    quote do
      unquote(func_name)(
        unquote_splicing(typespec(required_in)),
        unquote(optional_args_typespec(optional_in))
      ) ::
        unquote(bang_output_typespec(required_out, optional_out))
    end
  end

  def operation_call(name, args, opts) do
    operation_call(name, args, opts, operation_args_spec(name))
  end

  def operation_call(name, args, opts, %{desc: _} = spec) do
    nif_args = cast_arguments_to_nif_terms(args, opts, spec.in_req_spec, spec.in_opt_spec)

    case Vix.Nif.nif_vips_operation_call(name, nif_args) do
      {:ok, nif_out_args} ->
        output_to_erl_terms(
          nif_out_args,
          Map.new(spec.out_req_spec, &{&1.param_name, &1}),
          Map.new(spec.out_opt_spec, &{&1.param_name, &1})
        )

      {:error, {label, error}} ->
        {:error, String.trim("#{label}: #{error}")}

      {:error, term} ->
        {:error, term}
    end
  end

  def cast_arguments_to_nif_terms(args, _opts, args_spec, _opts_spec)
      when length(args) != length(args_spec) do
    {:error, "Expected #{length(args_spec)} required arguments, got #{length(args)}"}
  end

  def cast_arguments_to_nif_terms(args, opts, args_spec, opts_spec) do
    args_values =
      Enum.zip(args_spec, args)
      |> Enum.map(fn {%{param_name: param_name}, value} ->
        {param_name, value}
      end)

    opt_values =
      Enum.map(opts, fn {name, value} ->
        {Atom.to_string(name), value}
      end)

    all_args_values = args_values ++ opt_values
    all_args_spec = Map.new(args_spec ++ opts_spec, &{&1.param_name, &1})
    input_to_nif_terms(all_args_values, all_args_spec)
  end

  defp vips_operation_arguments(name) do
    {description, args} = Nif.nif_vips_operation_get_arguments(name)

    args =
      Enum.map(args, fn {name, spec_details, priority, flags} ->
        {desc, spec_type, value_type, data} = spec_details

        GParamSpec.new(%{
          name: name,
          desc: desc,
          spec_type: spec_type,
          value_type: value_type,
          data: data,
          priority: priority,
          flags: flags
        })
      end)

    {description, args}
  end

  defp pspec_type(pspec), do: GParamSpec.type(pspec)

  defp default(pspec) do
    type = pspec_type(pspec)
    data = pspec.data

    if Type.default(type, data) == :unsupported do
      ""
    else
      "Default: `#{inspect(Type.default(type, data))}`"
    end
  end

  defp optional_in_doc([]), do: ""

  defp optional_in_doc(optional_in) do
    optional_args =
      Enum.map_join(optional_in, "\n", fn pspec ->
        "* #{pspec.param_name} - #{pspec.desc}. #{default(pspec)}"
      end)

    """
    ## Optional
    #{optional_args}
    """
  end

  defp required_in_doc(required_in) do
    Enum.map_join(required_in, "\n", fn pspec ->
      "  * #{pspec.param_name} - #{pspec.desc}"
    end)
  end

  def output_values_doc([], []), do: ""
  def output_values_doc([_], []), do: ""

  def output_values_doc(required_out, optional_out) do
    required_out_values =
      Enum.map_join(required_out, "\n", fn pspec ->
        "* #{pspec.param_name} - #{pspec.desc}. (`#{Macro.to_string(typespec(pspec))}`)"
      end)

    optional_out_values =
      Enum.map_join(optional_out, "\n", fn pspec ->
        "* #{pspec.param_name} - #{pspec.desc}. (`#{Macro.to_string(typespec(pspec))}`)"
      end)

    """
    ## Returns
    Ordered values in the returned tuple
    #{required_out_values}

    ## Additional
    Last value of the the output tuple is a keyword list of additional optional output values
    #{optional_out_values}
    """
  end

  defp typespec(%GParamSpec{} = pspec) do
    case pspec_type(pspec) do
      {:enum, name} ->
        type_name(name)

      {:flags, name} ->
        type_name(name)

      type ->
        Type.typespec(type)
    end
  end

  defp typespec(pspec_list) when is_list(pspec_list) do
    Enum.map(pspec_list, &typespec/1)
  end

  defp optional_args_typespec(optional) do
    Enum.map(optional, fn pspec ->
      {String.to_atom(pspec.param_name), typespec(pspec)}
    end)
  end
end

defmodule Vix.Vips.Operation do
  @moduledoc """
  Vips Operations

  See libvips
  [documentation](https://libvips.github.io/libvips/API/current/func-list.html)
  for more detailed description of the operation.

  Vips operation functions are generated using vips-introspection and
  are up-to-date with libvips version installed. Documentation in the
  hexdocs might *not* match for you.
  """

  import Vix.Vips.OperationHelper

  defmodule Error do
    defexception [:message]
  end

  # define typespec for enums
  Enum.map(vips_enum_list(), fn {name, enum} ->
    {enum_str_list, _} = Enum.unzip(enum)
    @type unquote(type_name(name)) :: unquote(atom_typespec_ast(enum_str_list))
  end)

  # define typespec for flags
  Enum.map(vips_flag_list(), fn {name, flag} ->
    {flag_str_list, _} = Enum.unzip(flag)
    @type unquote(type_name(name)) :: list(unquote(atom_typespec_ast(flag_str_list)))
  end)

  # define operations
  Enum.map(vips_operation_list(), fn name ->
    %{
      desc: desc,
      in_req_spec: in_req_spec,
      in_opt_spec: in_opt_spec,
      out_req_spec: out_req_spec,
      out_opt_spec: out_opt_spec
    } = spec = operation_args_spec(name)

    func_name = function_name(name)

    req_params =
      Enum.map(in_req_spec, fn param ->
        param.param_name
        |> String.to_atom()
        |> Macro.var(__MODULE__)
      end)

    @doc """
    #{prepare_doc(desc, in_req_spec, in_opt_spec, out_req_spec, out_opt_spec)}
    """
    @spec unquote(func_typespec(func_name, in_req_spec, in_opt_spec, out_req_spec, out_opt_spec))
    def unquote(func_name)(unquote_splicing(req_params), optional \\ []) do
      operation_call(unquote(name), unquote(req_params), optional, unquote(Macro.escape(spec)))
    end

    bang_func_name = function_name(String.to_atom(name <> "!"))

    @doc """
    Same as `#{func_name}/#{length(req_params) + 1}`, except it
    returns only the value (not a tuple) and raises on error.
    """
    @spec unquote(
            bang_func_typespec(
              bang_func_name,
              in_req_spec,
              in_opt_spec,
              out_req_spec,
              out_opt_spec
            )
          )
    def unquote(bang_func_name)(unquote_splicing(req_params), optional \\ []) do
      case __MODULE__.unquote(func_name)(unquote_splicing(req_params), optional) do
        :ok -> :ok
        {:ok, result} -> result
        {:error, reason} when is_binary(reason) -> raise Error, message: reason
        {:error, reason} -> raise Error, message: inspect(reason)
      end
    end
  end)
end
