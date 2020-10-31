defmodule Eips.VipsOperation do
  alias Eips.Nif
  alias Eips.VipsOperationParam

  @ops_list Nif.nif_vips_operation_list()
            |> Enum.uniq_by(fn {name, _, _} -> name end)
            |> Enum.map(fn {name, desc, op_usage} ->
              func_name = "vips_#{name}" |> String.to_atom()

              name = List.to_atom(name)
              desc = to_string(desc)
              op_usage = to_string(op_usage)

              {required, optional} =
                VipsOperationParam.vips_operation_arguments(to_charlist(name))

              spec_map = Map.merge(required, optional)

              func_args =
                Enum.map(required, fn {field, _} ->
                  Macro.var(field, __MODULE__)
                end)

              nif_args =
                Enum.map(required, fn {field, _} ->
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

                nif_args =
                  (unquote(nif_args) ++ nif_optional_args)
                  |> Enum.map(fn {name, value} ->
                    {param_type_name, value_type_name} =
                      Map.get(unquote(Macro.escape(spec_map)), List.to_atom(name))

                    {name, VipsOperationParam.cast(value, param_type_name, value_type_name)}
                  end)

                Eips.Nif.nif_vips_operation_call(
                  unquote(Atom.to_charlist(name)),
                  nif_args
                )
              end
            end)

  def vips_ops_list, do: @ops_list
end
