defmodule Vix.Vips.Operation.Helper do
  @moduledoc false

  alias Vix.GObject.GParamSpec
  alias Vix.Nif
  alias Vix.Type
  alias Vix.Vips.Operation.Error

  def input_to_nif_terms(args, in_pspec) do
    args
    |> Enum.reduce([], fn {name, value}, terms ->
      # skip unsupported additional arguments
      case Map.fetch(in_pspec, name) do
        :error ->
          terms

        {:ok, pspec} ->
          term = Type.to_nif_term(pspec.type, value, pspec.data)
          [{name, term} | terms]
      end
    end)
  end

  def vips_enum_list do
    Nif.nif_vips_enum_list()
  end

  def vips_flag_list do
    Nif.nif_vips_flag_list()
  end

  def vips_immutable_operation_list do
    vips_operation_list()
    |> Enum.reject(&mutable_operation?/1)
  end

  def vips_mutable_operation_list do
    vips_operation_list()
    |> Enum.filter(&mutable_operation?/1)
  end

  def vips_operation_list do
    Nif.nif_vips_operation_list()
    |> Enum.uniq()
    |> Enum.reject(&unsupported_operation?/1)
  end

  def output_to_erl_terms(nif_out_args, required_out_pspec, optional_out_pspec) do
    {required, optional} =
      nif_out_args
      |> Enum.reduce({[], []}, fn {param, value}, {required, optional} ->
        cond do
          Map.has_key?(required_out_pspec, param) ->
            pspec = Map.get(required_out_pspec, param)
            value = Type.to_erl_term(pspec.type, value)
            {[{pspec.priority, value} | required], optional}

          Map.has_key?(optional_out_pspec, param) ->
            pspec = Map.get(optional_out_pspec, param)
            value = Type.to_erl_term(pspec.type, value)
            {required, [{String.to_atom(param), value} | optional]}

          true ->
            raise Error, message: "Invalid operation output field: #{param}"
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

      {required, []} ->
        {:ok, List.to_tuple(required)}

      {required, optional} ->
        {:ok, List.to_tuple(required ++ [Map.new(optional)])}
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
        Type.supported?(pspec.type)
      end)

    required_input = Enum.sort_by(required_input, & &1.priority)
    required_output = Enum.sort_by(required_output, & &1.priority)

    %{
      desc: desc,
      in_req_spec: required_input,
      in_opt_spec: optional_input,
      out_req_spec: required_output,
      out_opt_spec: optional_output
    }
  end

  def function_name(name), do: to_string(name) |> String.downcase() |> String.to_atom()

  def normalize_input_variable_names(specs) do
    Enum.map(specs, fn
      %{param_name: "in"} = param ->
        %{param | param_name: "input"}

      param ->
        param
    end)
  end

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

      {pspec_list, []} ->
        quote do
          {:ok, {unquote_splicing(required_args_typespec(pspec_list))}}
          | {:error, term()}
        end

      {pspec_list, optional} ->
        optional_out = optional_args_typespec(optional)

        quote do
          {:ok,
           {unquote_splicing(required_args_typespec(pspec_list)),
            %{unquote_splicing(optional_out)}}}
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

      {pspec_list, []} ->
        quote do
          {unquote_splicing(required_args_typespec(pspec_list))}
          | no_return()
        end

      {pspec_list, optional} ->
        optional_out = optional_args_typespec(optional)

        quote do
          {unquote_splicing(required_args_typespec(pspec_list)),
           %{unquote_splicing(optional_out)}}
          | no_return()
        end
    end
  end

  def func_typespec(func_name, required_in, optional_in, required_out, optional_out) do
    quote do
      unquote(func_name)(
        unquote_splicing(
          if optional_in == [] do
            required_args_typespec(required_in)
          else
            required_args_typespec(required_in) ++ [optional_args_typespec(optional_in)]
          end
        )
      ) ::
        unquote(output_typespec(required_out, optional_out))
    end
  end

  def bang_func_typespec(func_name, required_in, optional_in, required_out, optional_out) do
    quote do
      unquote(func_name)(
        unquote_splicing(
          if optional_in == [] do
            required_args_typespec(required_in)
          else
            required_args_typespec(required_in) ++ [optional_args_typespec(optional_in)]
          end
        )
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

  defp mutable_operation?(operation_name) do
    {_desc, args} = vips_operation_arguments(operation_name)

    Enum.any?(args, fn %{type: type} ->
      type == "MutableVipsImage"
    end)
  end

  defp unsupported_operation?(operation_name) do
    {_desc, args} = vips_operation_arguments(operation_name)

    Enum.any?(args, fn %{value_type: value_type} ->
      value_type == "VipsSource" || value_type == "VipsTarget"
    end)
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

  defp default(pspec) do
    type = pspec.type
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

    """
    ## Returns
    Operation returns a tuple

    #{required_out_values}

    #{optional_out_doc(optional_out)}
    """
  end

  defp optional_out_doc([]), do: ""

  defp optional_out_doc(optional_out) do
    optional_out_values =
      Enum.map_join(optional_out, "\n", fn pspec ->
        "* #{pspec.param_name} - #{pspec.desc}. (`#{Macro.to_string(typespec(pspec))}`)"
      end)

    """
    Last value of the tuple is a map of additional output values as key-value pair.
    #{optional_out_values}
    """
  end

  defp typespec(%GParamSpec{} = pspec) do
    case pspec.type do
      {:enum, name} ->
        type_name(name)

      {:flags, name} ->
        type_name(name)

      type ->
        Type.typespec(type)
    end
  end

  defp required_args_typespec(psepc_list) do
    Enum.map(psepc_list, &typespec/1)
  end

  defp optional_args_typespec(psepc_list) do
    Enum.map(psepc_list, fn pspec ->
      {String.to_atom(pspec.param_name), typespec(pspec)}
    end)
  end
end
