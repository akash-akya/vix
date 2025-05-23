defmodule Vix.Vips.OperationTest do
  use ExUnit.Case, async: true

  alias Vix.Vips.Image
  alias Vix.Vips.Operation

  import Vix.Support.Images

  test "invert" do
    {:ok, im} = Image.new_from_file(img_path("puppies.jpg"))
    assert {:ok, out} = Operation.invert(im)

    out_path = Briefly.create!(extname: ".jpg")
    :ok = Image.write_to_file(out, out_path)

    assert_files_equal(img_path("invert_puppies.jpg"), out_path)
  end

  test "affine" do
    {:ok, im} = Image.new_from_file(img_path("puppies.jpg"))
    assert {:ok, out} = Operation.affine(im, [1, 0, 0, 0.5])

    out_path = Briefly.create!(extname: ".jpg")
    :ok = Image.write_to_file(out, out_path)

    assert_files_equal(img_path("affine_puppies.jpg"), out_path)
  end

  test "gravity" do
    {:ok, im} = Image.new_from_file(img_path("puppies.jpg"))

    assert {:ok, out} =
             Operation.gravity(im, :VIPS_COMPASS_DIRECTION_CENTRE, 650, 500,
               extend: :VIPS_EXTEND_COPY
             )

    out_path = Briefly.create!(extname: ".jpg")
    :ok = Image.write_to_file(out, out_path)

    assert_files_equal(img_path("gravity_puppies.jpg"), out_path)
  end

  test "conv with simple edge detection kernel" do
    {:ok, im} = Image.new_from_file(img_path("puppies.jpg"))
    {:ok, mask} = Image.new_matrix_from_array(3, 3, [[-1, -1, -1], [-1, 8, -1], [-1, -1, -1]])

    assert {:ok, out} = Operation.conv(im, mask, precision: :VIPS_PRECISION_FLOAT)

    out_path = Briefly.create!(extname: ".jpg")
    :ok = Image.write_to_file(out, out_path)

    assert_files_equal(img_path("conv_puppies.jpg"), out_path)
  end

  test "additional return values" do
    {:ok, im} = Image.new_from_file(img_path("black_on_white.jpg"))

    assert {:ok, {min, %{x: _, y: _, "out-array": [min], "x-array": [_ | _], "y-array": [_ | _]}}} =
             Operation.min(im)

    assert min in [-0.0, +0.0]
  end

  test "required output order" do
    {:ok, im} = Image.new_from_file(img_path("black_on_white.jpg"))
    assert Operation.find_trim(im) == {:ok, {41, 44, 45, 45}}
  end

  test "when unsupported argument is passed" do
    buf = File.read!(img_path("alpha_band.png"))
    assert {:ok, {%Image{}, _}} = Operation.pngload_buffer(buf, foo: "bar")
  end

  test "operation error" do
    {:ok, im} = Image.new_from_file(img_path("black_on_white.jpg"))

    assert Operation.affine(im, [1, 1, 1, 1]) ==
             {:error,
              "operation build: vips__transform_calc_inverse: singular or near-singular matrix"}
  end

  test "image type mismatch error" do
    assert_raise ArgumentError, "expected Vix.Vips.Image. given: :invalid", fn ->
      Operation.invert(:invalid)
    end
  end

  test "enum parameter" do
    {:ok, im} = Image.new_from_file(img_path("black_on_white.jpg"))
    {:ok, out} = Operation.flip(im, :VIPS_DIRECTION_HORIZONTAL)

    out_path = Briefly.create!(extname: ".jpg")
    :ok = Image.write_to_file(out, out_path)

    assert_files_equal(img_path("black_on_white_hflip.jpg"), out_path)
  end
end
