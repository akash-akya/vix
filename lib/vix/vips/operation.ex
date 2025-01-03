defmodule Vix.Vips.Operation do
  @moduledoc """
  Provides access to VIPS operations for image processing.

  This module exposes VIPS operations as Elixir functions, allowing you to perform
  various image processing tasks like resizing, color manipulation, filtering,
  and format conversion.

  ## Quick Start

  Here's a simple example to resize an image:

      # Load and resize an image to 500px width, maintaining aspect ratio
      {:ok, image} = Operation.thumbnail("input.jpg", 500)

  ## Working with Operations

  Operations in Vix can be grouped into several categories:

  * **Loading/Saving** - `Vix.Vips.Image`, `thumbnail/2`, and format specific functions.
  * **Resizing** - `resize/2`, `thumbnail/2`, `smartcrop/3`
  * **Color Management** - `colourspace/2`, `icc_transform/2`
  * **Filters & Effects** - `gaussblur/2`, `sharpen/2`
  * **Composition** - `composite/3`, `join/3`, `insert/4`

  Most operations follow a consistent pattern:

  1. Load your image
  2. Apply one or more operations
  3. Save the result

  ## Common Examples

      # Basic image resizing while preserving aspect ratio
      {:ok, image} = Vix.Vips.Image.new_from_file("input.jpg")
      # scale down by 50%
      {:ok, resized} = Operation.resize(image, scale: 0.5)
      :ok = Vix.Vips.Image.write_to_file(resized, "output.jpg")

      # Convert to grayscale and apply Gaussian blur
      {:ok, image} = Vix.Vips.Image.new_from_file("input.jpg")
      {:ok, gray} = Operation.colourspace(image, :VIPS_INTERPRETATION_B_W)
      {:ok, blurred} = Operation.gaussblur(gray, 3.0)

  ## Advanced Usage

  ### Smart Cropping for Thumbnails

      # Generate a smart-cropped thumbnail focusing on interesting areas
      {:ok, thumb} = Operation.thumbnail("input.jpg", 300,
        crop: :attention,  # Uses image analysis to find interesting areas
        height: 300,      # Force square thumbnail
      )

  ### Complex Image Composition

      # Create a watermarked image with transparency
      {:ok, base} = Vix.Vips.Image.new_from_file("photo.jpg")
      {:ok, watermark} = Vix.Vips.Image.new_from_file("watermark.png")
      {:ok, composed} = Operation.composite2(base, watermark,
        :VIPS_BLEND_MODE_OVER,  # Blend mode
        x: 20,         # Offset from left
        y: 20,         # Offset from top
        opacity: 0.8   # Watermark transparency
      )

  ### Color Management

      # Convert between color spaces with ICC profiles
      {:ok, image} = Vix.Vips.Image.new_from_file("input.jpg")
      {:ok, converted} = Operation.icc_transform(image,
        "sRGB.icc",     # Target color profile
        "input-profile": "Adobe-RGB.icc"
      )


  > ## Performance Tips {: .tip}
  >
  > * Use `thumbnail/2` instead of `resize/2` when possible - it's optimized for common cases
  > * Chain operations to avoid intermediate file I/O
  > * For batch processing, reuse loaded ICC profiles and watermarks
  > * Consider using sequential mode for large images

  ## Additional Resources

  * [VIPS Documentation](https://www.libvips.org/API/current/)

  <!-- TODO: Add section about memory management best practices -->
  <!-- TODO: Add examples for animation handling -->
  <!-- TODO: Document format-specific options for loading/saving -->
  <!-- TODO: Add common recipes for web image optimization -->

  """

  import Vix.Vips.Operation.Helper

  alias Vix.Vips.Operation.Error

  # define typespec for enums
  Enum.map(vips_enum_list(), fn {name, enum} ->
    {enum_str_list, _} = Enum.unzip(enum)
    @type unquote(type_name(name)) :: unquote(atom_typespec_ast(enum_str_list))
  end)

  # define typespec for flags
  Enum.map(vips_flag_list(), fn {name, flag} ->
    {flag_str_list, _} = Enum.unzip(flag)
    @type unquote(type_name(name)) :: list(unquote(atom_typespec_ast(flag_str_list)))
  end)

  Enum.map(vips_immutable_operation_list(), fn name ->
    %{
      desc: desc,
      in_req_spec: in_req_spec,
      in_opt_spec: in_opt_spec,
      out_req_spec: out_req_spec,
      out_opt_spec: out_opt_spec
    } = spec = operation_args_spec(name)

    func_name = function_name(name)
    in_req_spec = normalize_input_variable_names(in_req_spec)

    req_params =
      Enum.map(in_req_spec, fn param ->
        param.param_name
        |> String.to_atom()
        |> Macro.var(__MODULE__)
      end)

    @doc """
    #{prepare_doc(desc, in_req_spec, in_opt_spec, out_req_spec, out_opt_spec)}
    """
    @spec unquote(func_typespec(func_name, in_req_spec, in_opt_spec, out_req_spec, out_opt_spec))
    if in_opt_spec == [] do
      # operations without optional arguments
      def unquote(func_name)(unquote_splicing(req_params)) do
        operation_call(unquote(name), unquote(req_params), [], unquote(Macro.escape(spec)))
      end
    else
      # operations with optional arguments
      def unquote(func_name)(unquote_splicing(req_params), optional \\ []) do
        operation_call(unquote(name), unquote(req_params), optional, unquote(Macro.escape(spec)))
      end
    end

    bang_func_name = function_name(String.to_atom(name <> "!"))

    @doc """
    #{prepare_doc(desc, in_req_spec, in_opt_spec, out_req_spec, out_opt_spec)}
    """
    @spec unquote(
            bang_func_typespec(
              bang_func_name,
              in_req_spec,
              in_opt_spec,
              out_req_spec,
              out_opt_spec
            )
          )
    if in_opt_spec == [] do
      @dialyzer {:no_match, [{bang_func_name, length(req_params)}]}
      # operations without optional arguments
      def unquote(bang_func_name)(unquote_splicing(req_params)) do
        case __MODULE__.unquote(func_name)(unquote_splicing(req_params)) do
          :ok -> :ok
          {:ok, result} -> result
          {:error, reason} when is_binary(reason) -> raise Error, message: reason
          {:error, reason} -> raise Error, message: inspect(reason)
        end
      end
    else
      @dialyzer {:no_match, [{bang_func_name, length(req_params) + 1}]}
      # operations with optional arguments
      def unquote(bang_func_name)(unquote_splicing(req_params), optional \\ []) do
        case __MODULE__.unquote(func_name)(unquote_splicing(req_params), optional) do
          :ok -> :ok
          {:ok, result} -> result
          {:error, reason} when is_binary(reason) -> raise Error, message: reason
          {:error, reason} -> raise Error, message: inspect(reason)
        end
      end
    end
  end)
end
