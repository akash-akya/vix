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
    module_name = Module.concat(Vix.Vips.Enum, List.to_atom(name))
    {enum_str_list, _} = Enum.unzip(enum)

    spec = Enum.reduce(enum_str_list, &{:|, [], [&1, &2]})

    contents =
      quote do
        @type t() :: unquote(spec)

        alias Vix.Type

        @behaviour Type

        @impl Type
        def spec_type, do: "GParamEnum"

        @impl Type
        def value_type, do: unquote(to_string(name))

        @impl Type
        def typespec do
          quote do
            unquote(__MODULE__).t()
          end
        end

        unquote(
          Enum.map(enum, fn {name, value} ->
            quote do
              @impl Type
              def new(unquote(name), _data), do: unquote(value)
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
