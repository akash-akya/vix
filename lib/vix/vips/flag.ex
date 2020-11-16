defmodule Vix.Vips.FlagHelper do
  @moduledoc false

  def __before_compile__(env) do
    Vix.Nif.nif_vips_flag_list()
    |> Enum.map(fn {name, flag} ->
      def_vips_flag(name, flag, env)
    end)

    quote do
    end
  end

  def def_vips_flag(name, flag, env) do
    module_name = Module.concat(Vix.Vips.Flag, List.to_atom(name))
    {flag_str_list, _} = Enum.unzip(flag)

    spec = Enum.reduce(flag_str_list, &{:|, [], [&1, &2]})

    contents =
      quote do
        # Internal module
        @moduledoc false
        use Bitwise, only_operators: true
        @type t() :: unquote(spec)

        alias Vix.Type

        @behaviour Type

        @impl Type
        def typespec do
          quote do
            list(unquote(__MODULE__).t())
          end
        end

        @impl Type
        def default(default), do: default

        @impl Type
        def cast(flags, _data) do
          Enum.reduce(flags, 0, fn flag, value ->
            value ||| cast(flag)
          end)
        end

        unquote(
          Enum.map(flag, fn {name, value} ->
            quote do
              defp cast(unquote(name)), do: unquote(value)
            end
          end)
        )
      end

    Module.create(module_name, contents, line: env.line, file: env.file)
  end
end

defmodule Vix.Vips.Flag do
  @moduledoc false
  @before_compile Vix.Vips.FlagHelper
end
