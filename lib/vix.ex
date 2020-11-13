defmodule Vix do
  alias Vix.Operation, as: Vips
  alias Vix.Vips.Image

  ### TEST

  def vips_affine(a_vi, list), do: Vips.affine(a_vi, list)

  def vips_invert(a_vi), do: Vips.invert(a_vi)

  def vips_add(left, right), do: Vips.add(left, right)

  def vips_flip(in_img, direction), do: Vips.flip(in_img, direction)

  def vips_embed(in_img, x, y, width, height, optional \\ []) do
    Vips.embed(in_img, x, y, width, height, optional)
  end

  def run_vips_affine(input, int_list, output) do
    input = to_charlist(input)
    output = to_charlist(output)

    {:ok, vi} = Image.new_from_file(input)
    [output_vi] = vips_affine(vi, int_list)
    Image.write_to_file(output_vi, output)
  end

  def run_vips_gravity(input, output, direction, width, height, optional \\ []) do
    input = to_charlist(input)
    output = to_charlist(output)

    {:ok, vi} = Image.new_from_file(input)

    Vips.gravity(vi, direction, width, height, optional)
    |> Image.write_to_file(output)
  end

  def run_vips_embed(input, output, x, y, width, height, optional \\ []) do
    input = to_charlist(input)
    output = to_charlist(output)

    {:ok, vi} = Image.new_from_file(input)
    [output_vi] = vips_embed(vi, x, y, width, height, optional)
    Image.write_to_file(output_vi, output)
  end

  def run_example(input_a, input_b, output) do
    input_a = to_charlist(input_a)
    input_b = to_charlist(input_b)
    output = to_charlist(output)

    {:ok, a_vi} = Image.new_from_file(input_a)
    {:ok, _b_vi} = Image.new_from_file(input_b)

    [output_vi] = vips_flip(a_vi, :VIPS_DIRECTION_VERTICAL)
    [output_vi] = vips_invert(output_vi)

    Image.write_to_file(output_vi, output)
  end
end
