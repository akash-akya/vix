defmodule Eips do
  alias Eips.Nif

  def invert(src, dst) do
    Nif.invert(to_charlist(src), to_charlist(dst))
  end

  def gintro, do: Nif.gintro()

  def inspect_op(op), do: Nif.inspect_op(to_charlist(op))

  def create_operation(name) do
    Nif.nif_create_op(to_charlist(name))
  end

  def get_operation_args(op) do
    Nif.nif_get_op_arguments(op)
    |> Enum.map(fn {param_name, {param_class, gtype, priority, offset}, flags} ->
      %{
        param_name: to_string(param_name),
        spec: %{class: to_string(param_class), gtype: gtype, priority: priority, offset: offset},
        flags: flags
      }
    end)
  end

  def image_from_file(path) do
    Nif.nif_image_new_from_file(to_charlist(path))
  end

  def run_vips_operation(name, input_params, output_params) do
    result = Nif.nif_operation_call_with_args(name, input_params, output_params)

    Enum.zip(output_params, result)
    |> Enum.map(fn {{name, type}, res} ->
      {name, type, res}
    end)
  end

  def write_vips_image(vips_image, path) do
    Nif.nif_image_write_to_file(vips_image, path)
  end

  ### TEST

  def vips_invert(input_vi) do
    {:ok, input_g_obj} = Nif.nif_vips_object_to_g_object(input_vi)

    [{'out', 'VipsImage', output_g_obj}] =
      run_vips_operation(
        'invert',
        [{'in', 'VipsImage', input_g_obj}],
        [{'out', 'VipsImage'}]
      )

    Nif.nif_g_object_to_vips_object(output_g_obj)
  end

  def vips_flip(input_vi) do
    {:ok, input_g_obj} = Nif.nif_vips_object_to_g_object(input_vi)

    [{'out', 'VipsImage', output_g_obj}] =
      run_vips_operation(
        'flip',
        [{'in', 'VipsImage', input_g_obj}],
        [{'out', 'VipsImage'}]
      )

    Nif.nif_g_object_to_vips_object(output_g_obj)
  end

  def vips_add(a_vi, b_vi) do
    {:ok, a_g_obj} = Nif.nif_vips_object_to_g_object(a_vi)
    {:ok, b_g_obj} = Nif.nif_vips_object_to_g_object(b_vi)

    [{'out', 'VipsImage', output_g_obj}] =
      run_vips_operation(
        'add',
        [{'left', 'VipsImage', a_g_obj}, {'right', 'VipsImage', b_g_obj}],
        [{'out', 'VipsImage'}]
      )

    Nif.nif_g_object_to_vips_object(output_g_obj)
  end

  def run_example(input_a, input_b, output) do
    input_a = to_charlist(input_a)
    input_b = to_charlist(input_b)
    output = to_charlist(output)

    {:ok, a_vi} = image_from_file(input_a)
    {:ok, b_vi} = image_from_file(input_b)

    output_vi =
      vips_add(a_vi, b_vi)
      |> vips_invert()

    write_vips_image(output_vi, output)
  end

  # def vips_invert(input_path, output_path) do
  #   input_path = to_charlist(input_path)
  #   output_path = to_charlist(output_path)

  #   {:ok, im} = image_from_file(input_path)
  #   {:ok, gim} = Nif.nif_vips_object_to_g_object(im)

  #   [{'out', 'VipsImage', output_image}] =
  #     run_vips_operation(
  #       'invert',
  #       [{'in', 'VipsImage', gim}],
  #       [{'out', 'VipsImage'}]
  #     )

  #   vips_image = Nif.nif_g_object_to_vips_object(output_image)
  #   write_vips_image(vips_image, output_path)
  # end

  # def vips_add(image_a, image_b, output_path) do
  #   image_a = to_charlist(image_a)
  #   image_b = to_charlist(image_b)
  #   output_path = to_charlist(output_path)

  #   {:ok, img_a} = image_from_file(image_a)
  #   {:ok, img_a} = Nif.nif_vips_object_to_g_object(img_a)

  #   {:ok, img_b} = image_from_file(image_b)
  #   {:ok, img_b} = Nif.nif_vips_object_to_g_object(img_b)

  #   [{'out', 'VipsImage', output_image}] =
  #     run_vips_operation(
  #       'add',
  #       [{'left', 'VipsImage', img_a}, {'right', 'VipsImage', img_b}],
  #       [{'out', 'VipsImage'}]
  #     )

  #   vips_image = Nif.nif_g_object_to_vips_object(output_image)
  #   write_vips_image(vips_image, output_path)
  # end
end
