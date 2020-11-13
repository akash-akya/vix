defmodule Vix.Operation do
  alias Vix.Nif
  alias Vix.Param
  alias Vix.Type

  Nif.nif_vips_operation_list()
  |> Enum.uniq_by(fn {name, _, _} -> name end)
  |> Enum.map(fn {name, desc, _op_usage} ->
    func_name = to_string(name) |> String.downcase() |> String.to_atom()
    name = List.to_atom(name)
    desc = to_string(desc)

    args = Param.vips_operation_arguments(to_charlist(name))

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

    input_args = Map.new(input, &{&1.param_name, &1})

    required = Enum.sort_by(required, & &1.priority)

    func_args = Enum.map(required, &Macro.var(&1.param_name, __MODULE__))

    doc_required_args =
      Enum.map_join(required, "\n", fn pspec ->
        "  * #{pspec.param_name} - #{pspec.desc}"
      end)

    doc_optional_args =
      Enum.map_join(optional, "\n", fn pspec ->
        "  * #{pspec.param_name} - #{pspec.desc}"
      end)

    nif_args =
      Enum.map(required, fn pspec ->
        {Atom.to_charlist(pspec.param_name), Macro.var(pspec.param_name, __MODULE__)}
      end)

    @doc """
    #{desc}

    ## Arguments
    #{doc_required_args}

    ## Optional
    #{doc_optional_args}
    """
    @spec unquote(func_name)(
            unquote_splicing(
              Enum.map(required, fn pspec ->
                quote do
                  unquote(Type.typespec(pspec))
                end
              end)
            ),
            keyword()
          ) ::
            unquote(
              if length(output) == 1 do
                quote do
                  unquote(Type.typespec(hd(output)))
                end
              else
                quote do
                  list(term())
                end
              end
            )
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
          unquote(Atom.to_charlist(name)),
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
