defmodule Vix.Vips.FlagHelper do
  @moduledoc false

  def __before_compile__(env) do
    for {name, flag} <- Vix.Nif.nif_vips_flag_list() do
      def_vips_flag(name, flag, env)
    end

    quote do
    end
  end

  def def_vips_flag(name, flag, env) do
    module_name = Module.concat(Vix.Vips.Flag, name)
    {flag_str_list, _} = Enum.unzip(flag)

    spec = Enum.reduce(flag_str_list, &{:|, [], [&1, &2]})

    contents =
      quote do
        # Internal module
        @moduledoc false
        import Bitwise, only: [bor: 2]

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
        def to_nif_term(flags, _data) do
          Enum.reduce(flags, 0, fn flag, value ->
            bor(value, to_nif_term(flag))
          end)
        end

        @impl Type
        def to_erl_term(value) do
          Integer.to_string(value, 2)
          |> String.codepoints()
          |> Enum.map(fn v ->
            {v, ""} = Integer.parse(v, 2)
            erl_term(v)
          end)
        end

        unquote(
          Enum.map(flag, fn {name, value} ->
            quote do
              defp to_nif_term(unquote(name)), do: unquote(value)

              defp erl_term(unquote(value)), do: unquote(name)
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
