defmodule Vix.Vips.MutableOperation do
  @moduledoc """
  Module for Vix.Vips.MutableOperation.
  """

  import Vix.Vips.Operation.Helper

  alias Vix.Vips.Operation.Error

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

  Enum.map(vips_mutable_operation_list(), fn name ->
    %{
      desc: desc,
      in_req_spec: in_req_spec,
      in_opt_spec: in_opt_spec,
      out_req_spec: out_req_spec,
      out_opt_spec: out_opt_spec
    } = spec = operation_args_spec(name)

    # ensure only first param is mutable image
    [%{type: "MutableVipsImage"} | remaining_args] = in_req_spec ++ in_opt_spec

    if Enum.any?(remaining_args, &(&1.type == "MutableVipsImage")) do
      raise "Only first param can be MutableVipsImage"
    end

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
    if in_opt_spec == [] do
      # operations without optional arguments
      def unquote(func_name)(unquote_splicing(req_params)) do
        [mutable_image | rest_params] = unquote(req_params)

        operation_cb = fn image ->
          operation_call(
            unquote(name),
            [image | rest_params],
            [],
            unquote(Macro.escape(spec))
          )
        end

        GenServer.call(mutable_image.pid, {:operation, operation_cb})
      end
    else
      # operations with optional arguments
      def unquote(func_name)(unquote_splicing(req_params), optional \\ []) do
        [mutable_image | rest_params] = unquote(req_params)

        operation_cb = fn image ->
          operation_call(
            unquote(name),
            [image | rest_params],
            optional,
            unquote(Macro.escape(spec))
          )
        end

        GenServer.call(mutable_image.pid, {:operation, operation_cb})
      end
    end

    bang_func_name = function_name(String.to_atom(name <> "!"))

    @doc """
    #{prepare_doc(desc, in_req_spec, in_opt_spec, out_req_spec, out_opt_spec)}
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
    if in_opt_spec == [] do
      @dialyzer {:no_match, [{bang_func_name, length(req_params)}]}
      # operations without optional arguments
      def unquote(bang_func_name)(unquote_splicing(req_params)) do
        case __MODULE__.unquote(func_name)(unquote_splicing(req_params)) do
          :ok -> :ok
          {:ok, result} -> result
          {:error, reason} when is_binary(reason) -> raise Error, message: reason
          {:error, reason} -> raise Error, message: inspect(reason)
        end
      end
    else
      @dialyzer {:no_match, [{bang_func_name, length(req_params) + 1}]}
      # operations with optional arguments
      def unquote(bang_func_name)(unquote_splicing(req_params), optional \\ []) do
        case __MODULE__.unquote(func_name)(unquote_splicing(req_params), optional) do
          :ok -> :ok
          {:ok, result} -> result
          {:error, reason} when is_binary(reason) -> raise Error, message: reason
          {:error, reason} -> raise Error, message: inspect(reason)
        end
      end
    end
  end)
end
