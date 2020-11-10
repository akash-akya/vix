defmodule Vix.Operation do
  alias Vix.Nif
  alias Vix.Param
  alias Vix.Type
  alias Vix.GObject.GParamSpec

  Nif.nif_vips_operation_list()
  |> Enum.uniq_by(fn {name, _, _} -> name end)
  |> Enum.map(fn {name, desc, op_usage} ->
    func_name = List.to_atom(name)

    name = List.to_atom(name)
    desc = to_string(desc)
    # op_usage = to_string(op_usage)

    args = Param.vips_operation_arguments(to_charlist(name))

    {required, optional} =
      args
      |> Enum.split_with(fn {_, %{flags: flags}} ->
        :vips_argument_required in flags
      end)

    func_args =
      required
      |> Enum.sort_by(fn {_, param} -> param.priority end)
      |> Enum.map(fn {field_name, _} ->
        Macro.var(field_name, __MODULE__)
      end)

    doc_required_args =
      required
      |> Enum.sort_by(fn {_, param} -> param.priority end)
      |> Enum.map_join("\n", fn {name, param} ->
        "  * #{name} - #{param.desc}"
      end)

    doc_optional_args =
      optional
      |> Enum.map_join("\n", fn {name, param} ->
        "  * #{name} - #{param.desc}"
      end)

    nif_args =
      required
      |> Enum.sort_by(fn {_, param} -> param.priority end)
      |> Enum.map(fn {field_name, _} ->
        {Atom.to_charlist(field_name), Macro.var(field_name, __MODULE__)}
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
              Enum.map(required, fn {_name, param} ->
                quote do
                  unquote(Type.typespec(param))
                end
              end)
            ),
            keyword()
          ) :: [reference()]
    def unquote(func_name)(unquote_splicing(func_args), optional \\ []) do
      nif_optional_args =
        Enum.map(optional, fn {name, value} ->
          {Atom.to_charlist(name), value}
        end)

      nif_args =
        (unquote(nif_args) ++ nif_optional_args)
        |> Enum.map(fn {name, value} ->
          param_spec = Map.get(unquote(Macro.escape(args)), List.to_atom(name))
          {name, Type.new(value, param_spec)}
        end)

      Vix.Nif.nif_vips_operation_call(
        unquote(Atom.to_charlist(name)),
        nif_args
      )
    end
  end)
end
