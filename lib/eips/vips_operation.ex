defmodule Eips.VipsOperation do
  alias Eips.Nif

  @ops_list Nif.nif_vips_operation_list()
            |> Enum.map(fn {nickname, desc, op_usage} ->
              input_args =
                Nif.nif_vips_operation_get_arguments(nickname)
                |> Enum.map(fn {name, flags} -> {List.to_atom(name), flags} end)
                |> Enum.filter(fn {_name, flags} ->
                  Enum.member?(flags, :vips_argument_input)
                end)

              required =
                input_args
                |> Enum.filter(fn {_name, flags} ->
                  Enum.member?(flags, :vips_argument_required)
                end)
                |> Enum.map(fn {name, _} -> name end)

              optional =
                input_args
                |> Enum.filter(fn {_name, flags} ->
                  Enum.member?(flags, :vips_argument_optional)
                end)
                |> Enum.map(fn {name, _} -> name end)

              {List.to_atom(nickname), to_string(desc), to_string(op_usage), required, optional}
            end)
            |> Enum.uniq_by(fn {name, _, _, _, _} -> name end)

  @ops_list
  |> Enum.map(fn {op_name, desc, op_usage, required, _optional} ->
    func_name = "vips_#{Atom.to_string(op_name)}" |> String.to_atom()

    func_args =
      Enum.map(required, fn field ->
        Macro.var(field, __MODULE__)
      end)

    nif_args =
      Enum.map(required, fn field ->
        {Atom.to_charlist(field), Macro.var(field, __MODULE__)}
      end)

    # FIXME: using code block to preserve `op_usage` formatting. or
    # construct documentation from the GParamSpec
    @doc """
    #{desc}

    ```text
    #{op_usage}
    ```
    """
    def unquote(func_name)(unquote_splicing(func_args), optional \\ []) do
      nif_optional_args =
        Enum.map(optional, fn {name, value} ->
          {Atom.to_charlist(name), value}
        end)

      Eips.Nif.nif_vips_operation_call(
        unquote(Atom.to_charlist(op_name)),
        unquote(nif_args) ++ nif_optional_args
      )
    end
  end)

  def vips_ops_list, do: @ops_list
end
