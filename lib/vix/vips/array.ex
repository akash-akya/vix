defmodule Vix.Vips.ArrayHelper do
  @moduledoc false

  alias Vix.Nif
  alias Vix.Vips

  def __before_compile__(env) do
    def_vips_array(env, %{
      module_name: Int,
      nested_type: Vix.GObject.Int,
      nested_typespec: Macro.escape(quote(do: integer())),
      to_nif_term: &Nif.nif_int_array/1,
      to_erl_term: &Nif.nif_vips_int_array_to_erl_list/1
    })

    def_vips_array(env, %{
      module_name: Double,
      nested_type: Vix.GObject.Double,
      nested_typespec: Macro.escape(quote(do: float())),
      to_nif_term: &Nif.nif_double_array/1,
      to_erl_term: &Nif.nif_vips_double_array_to_erl_list/1
    })

    def_vips_array(env, %{
      module_name: Image,
      nested_type: Vips.Image,
      nested_typespec: Macro.escape(quote(do: Vips.Image.t())),
      to_nif_term: &Nif.nif_image_array/1,
      to_erl_term: &Nif.nif_vips_image_array_to_erl_list/1
    })

    # array of enum
    def_vips_array(env, %{
      module_name: Enum.VipsBlendMode,
      nested_type: Vips.Enum.VipsBlendMode,
      nested_typespec: Macro.escape(quote(do: Vips.Operation.vips_blend_mode())),
      to_nif_term: &Nif.nif_int_array/1,
      to_erl_term: &Nif.nif_vips_int_array_to_erl_list/1
    })
  end

  def def_vips_array(env, opts) do
    module_name = Module.concat([Vix.Vips.Array, opts.module_name])

    contents =
      quote do
        # Internal module
        @nested_type unquote(opts.nested_type)
        @to_nif_term unquote(opts.to_nif_term)
        @to_erl_term unquote(opts.to_erl_term)

        @moduledoc false
        @opaque t() :: reference()

        alias Vix.Type

        @behaviour Type

        @impl Type
        def typespec do
          nested_typespec = unquote(opts.nested_typespec)

          quote do
            list(unquote(nested_typespec))
          end
        end

        @impl Type
        def default(default), do: default

        @impl Type
        def to_nif_term(value, data) do
          Enum.map(value, fn nested_value ->
            @nested_type.to_nif_term(nested_value, data)
          end)
          |> @to_nif_term.()
        end

        @impl Type
        def to_erl_term(value) do
          {:ok, list} = @to_erl_term.(value)

          Enum.map(list, fn nested_value ->
            @nested_type.to_erl_term(nested_value)
          end)
        end
      end

    Module.create(module_name, contents, line: env.line, file: env.file)
  end
end

defmodule Vix.Vips.Array do
  @moduledoc false

  @before_compile Vix.Vips.ArrayHelper
end
