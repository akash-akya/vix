defmodule Vix.Vips.EnumHelper do
  @moduledoc false

  def __before_compile__(env) do
    Vix.Nif.nif_vips_enum_list()
    |> Enum.map(fn {name, enum} ->
      def_vips_enum(name, enum, env)
    end)

    quote do
    end
  end

  def def_vips_enum(name, enum, env) do
    module_name = String.to_atom("Elixir.Vix.Vips.Enum.#{name}")
    {enum_str_list, _} = Enum.unzip(enum)

    contents =
      quote do
        @type t() :: unquote(Enum.reduce(enum_str_list, &{:|, [], [&1, &2]}))

        unquote(
          Enum.map(enum, fn {name, value} ->
            quote do
              def cast(unquote(name)), do: unquote(value)
            end
          end)
        )
      end

    Module.create(module_name, contents, line: env.line, file: env.file)
  end
end

defmodule Vix.Vips.Enum do
  @before_compile Vix.Vips.EnumHelper
end
