defmodule Vix.Vips.EnumHelper do
  @moduledoc false

  def __before_compile__(env) do
    for {name, enum} <- Vix.Nif.nif_vips_enum_list() do
      def_vips_enum(name, enum, env)
    end

    quote do
    end
  end

  def def_vips_enum(name, enum, env) do
    module_name = Module.concat(Vix.Vips.Enum, name)
    {enum_str_list, _} = Enum.unzip(enum)

    spec = Enum.reduce(enum_str_list, &{:|, [], [&1, &2]})

    contents =
      quote do
        # Internal module
        @moduledoc false
        @type t() :: unquote(spec)

        alias Vix.Type

        @behaviour Type

        @impl Type
        def typespec do
          quote do
            unquote(__MODULE__).t()
          end
        end

        @impl Type
        def default(default), do: default

        unquote(
          Enum.map(enum, fn {name, value} ->
            quote do
              @impl Type
              def to_nif_term(unquote(name), _data), do: unquote(value)

              @impl Type
              def to_erl_term(unquote(value)), do: unquote(name)
            end
          end)
        )
      end

    Module.create(module_name, contents, line: env.line, file: env.file)
  end
end

defmodule Vix.Vips.Enum do
  @moduledoc false
  @before_compile Vix.Vips.EnumHelper
end
