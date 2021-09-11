defmodule Vix.Vips.OperationHelper do
  @moduledoc false

  alias Vix.Nif
  alias Vix.Type
  alias Vix.GObject.GParamSpec

  def input_to_nif_terms(args, in_pspec) do
    Enum.map(
      args,
      fn {name, value} ->
        param_spec = Map.get(in_pspec, name)
        {name, Type.to_nif_term(value, param_spec)}
      end
    )
  end

  def output_to_erl_terms(nif_out_args, required_out_pspec, optional_out_pspec) do
    {required, optional} =
      nif_out_args
      |> Enum.reduce({[], []}, fn {param, value}, {required, optional} ->
        cond do
          Map.has_key?(required_out_pspec, param) ->
            param_spec = Map.get(required_out_pspec, param)
            value = Type.to_erl_term(value, param_spec)
            {[{param_spec.priority, value} | required], optional}

          Map.has_key?(optional_out_pspec, param) ->
            param_spec = Map.get(optional_out_pspec, param)
            value = Type.to_erl_term(value, param_spec)
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
      # we do not support mutable operations yet. Skip operations which use un-supported types as arguments
      :vips_argument_modify in flags ||
        value_type == "VipsSource" ||
        value_type == "VipsTarget" ||
        value_type == "VipsBlob"
    end)
  end

  def operation_args(name) do
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

    # TODO: support VipsInterpolate and other types
    optional_input = Enum.filter(optional_input, &Type.supported?/1)

    required_input = Enum.sort_by(required_input, & &1.priority)
    required_output = Enum.sort_by(required_output, & &1.priority)
    {desc, required_input, optional_input, required_output, optional_output}
  end

  def function_name(name), do: to_string(name) |> String.downcase() |> String.to_atom()

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

  defp vips_operation_arguments(name) do
    {description, args} = Nif.nif_vips_operation_get_arguments(name)

    args =
      Enum.map(args, fn {name, spec_details, priority, flags} ->
        {desc, spec_type, value_type, data} = spec_details

        %GParamSpec{
          param_name: name,
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

  defp typespec(%GParamSpec{spec_type: "GParamEnum"} = pspec) do
    type_name(pspec.value_type)
  end

  defp typespec(%GParamSpec{spec_type: "GParamFlags"} = pspec) do
    type_name(pspec.value_type)
  end

  defp typespec(pspec_list) when is_list(pspec_list) do
    Enum.map(pspec_list, &typespec/1)
  end

  defp typespec(pspec), do: Type.typespec(pspec)

  defp optional_args_typespec(optional) do
    Enum.map(optional, fn pspec ->
      {String.to_atom(pspec.param_name), typespec(pspec)}
    end)
  end
end

defmodule Vix.Vips.Operation do
  @moduledoc """
  Vips Operations

  See libvips [documentation](https://libvips.github.io/libvips/API/current/func-list.html) for more detailed description of the operation.

  Vips operation functions are generated using vips-introspection and are up-to-date with libvips version installed. Documentation in the hexdocs might *not* match for you.
  """

  import Vix.Vips.OperationHelper

  alias Vix.Nif

  defmodule Error do
    defexception [:message]
  end

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
  |> Enum.reject(&reject_unsupported_operations/1)
  |> Enum.map(fn name ->
    {desc, required_in, optional_in, required_out, optional_out} = operation_args(name)

    func_name = function_name(name)

    func_params =
      Enum.map(required_in, fn param ->
        Macro.var(String.to_atom(param.param_name), __MODULE__)
      end)

    in_pspec = Map.new(required_in ++ optional_in, &{&1.param_name, &1})
    required_out_pspec = Map.new(required_out, &{&1.param_name, &1})
    optional_out_pspec = Map.new(optional_out, &{&1.param_name, &1})

    func_required_in_values =
      Enum.map(required_in, fn %{param_name: param_name} ->
        {param_name, Macro.var(String.to_atom(param_name), __MODULE__)}
      end)

    @doc """
    #{prepare_doc(desc, required_in, optional_in, required_out, optional_out)}
    """
    @spec unquote(
            func_typespec(
              func_name,
              required_in,
              optional_in,
              required_out,
              optional_out
            )
          )
    def unquote(func_name)(unquote_splicing(func_params), optional \\ []) do
      func_optional_in_values =
        Enum.map(optional, fn {name, value} ->
          {Atom.to_string(name), value}
        end)

      in_args = unquote(func_required_in_values) ++ func_optional_in_values
      nif_in_args = input_to_nif_terms(in_args, unquote(Macro.escape(in_pspec)))

      result =
        Vix.Nif.nif_vips_operation_call(
          unquote(name),
          nif_in_args
        )

      case result do
        {:ok, nif_out_args} ->
          output_to_erl_terms(
            nif_out_args,
            unquote(Macro.escape(required_out_pspec)),
            unquote(Macro.escape(optional_out_pspec))
          )

        {:error, {label, error}} ->
          {:error, String.trim("#{label}: #{error}")}

        {:error, term} ->
          {:error, term}
      end
    end

    bang_func_name = function_name(String.to_atom(name <> "!"))

    @doc """
    Same as `#{func_name}/#{length(func_params) + 1}`, except it returns only the value (not a tuple) and raises on error.
    """
    @spec unquote(
            bang_func_typespec(
              bang_func_name,
              required_in,
              optional_in,
              required_out,
              optional_out
            )
          )
    def unquote(bang_func_name)(unquote_splicing(func_params), optional \\ []) do
      case __MODULE__.unquote(func_name)(unquote_splicing(func_params), optional) do
        :ok -> :ok
        {:ok, result} -> result
        {:error, reason} when is_binary(reason) -> raise Error, message: reason
        {:error, reason} -> raise Error, message: inspect(reason)
      end
    end
  end)
end
