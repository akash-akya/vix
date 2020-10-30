defmodule Eips do
  alias Eips.Nif

  def image_from_file(path) do
    Nif.nif_image_new_from_file(to_charlist(path))
  end

  def run_vips_operation(name, input_params) do
    Nif.nif_vips_operation_call(name, input_params)
  end

  def write_vips_image(vips_image, path) do
    Nif.nif_image_write_to_file(vips_image, path)
  end

  ### TEST

  def vips_invert(input_vi) do
    [output_vi] =
      run_vips_operation(
        'invert',
        [{'in', input_vi}]
      )

    output_vi
  end

  def vips_flip(input_vi, direction) do
    [output_vi] =
      run_vips_operation(
        'flip',
        [{'in', input_vi}, {'direction', direction}]
      )

    output_vi
  end

  def vips_add(a_vi, b_vi) do
    [output_vi] =
      run_vips_operation(
        'add',
        [{'left', 'VipsImage', a_vi}, {'right', 'VipsImage', b_vi}]
      )

    output_vi
  end

  def vips_affine(a_vi, vips_double_array) do
    Eips.VipsOperation.vips_affine(a_vi, vips_double_array)
  end

  def vips_embed(in_img, x, y, width, height, optional \\ []) do
    Eips.VipsOperation.vips_embed(in_img, x, y, width, height, optional)
  end

  defp to_double(n), do: n * 1.0

  def run_vips_affine(input, int_list, output) do
    input = to_charlist(input)
    output = to_charlist(output)

    double_list = Enum.map(int_list, &to_double/1)
    vips_double_array = Eips.Nif.nif_double_array(double_list)

    {:ok, vi} = image_from_file(input)
    [output_vi] = vips_affine(vi, vips_double_array)
    write_vips_image(output_vi, output)
  end

  def run_vips_embed(input, output, x, y, width, height) do
    input = to_charlist(input)
    output = to_charlist(output)

    {:ok, vi} = image_from_file(input)
    [output_vi] = vips_embed(vi, x, y, width, height, extend: :VIPS_EXTEND_COPY)
    write_vips_image(output_vi, output)
  end

  def run_example(input_a, input_b, output) do
    input_a = to_charlist(input_a)
    input_b = to_charlist(input_b)
    output = to_charlist(output)

    {:ok, a_vi} = image_from_file(input_a)
    {:ok, _b_vi} = image_from_file(input_b)

    output_vi =
      vips_flip(a_vi, :VIPS_DIRECTION_HORIZONTAL)
      |> vips_invert()

    write_vips_image(output_vi, output)
  end
end
