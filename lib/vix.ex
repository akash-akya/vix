defmodule Vix do
  alias Vix.Nif
  alias Vix.Operation, as: Vips

  def image_from_file(path) do
    Nif.nif_image_new_from_file(to_charlist(path))
  end

  def write_vips_image(vips_image, path) do
    Nif.nif_image_write_to_file(vips_image, path)
  end

  ### TEST

  def vips_affine(a_vi, list), do: Vips.vips_affine(a_vi, list)

  def vips_invert(a_vi), do: Vips.vips_invert(a_vi)

  def vips_add(left, right), do: Vips.vips_add(left, right)

  def vips_flip(in_img, direction), do: Vips.vips_flip(in_img, direction)

  def vips_embed(in_img, x, y, width, height, optional \\ []) do
    Vips.vips_embed(in_img, x, y, width, height, optional)
  end

  def run_vips_affine(input, int_list, output) do
    input = to_charlist(input)
    output = to_charlist(output)

    # double_list = Enum.map(int_list, &to_double/1)
    # vips_double_array = Vix.Nif.nif_double_array(double_list)

    {:ok, vi} = image_from_file(input)
    [output_vi] = vips_affine(vi, int_list)
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
