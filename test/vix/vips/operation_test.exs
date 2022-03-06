defmodule Vix.Vips.OperationTest do
  use ExUnit.Case, async: true

  alias Vix.Vips.Image
  alias Vix.Vips.Operation

  import Vix.Support.Images

  setup do
    Temp.track!()
    dir = Temp.mkdir!()
    {:ok, %{dir: dir}}
  end

  test "invert", %{dir: dir} do
    {:ok, im} = Image.new_from_file(img_path("puppies.jpg"))
    assert {:ok, out} = Operation.invert(im)

    out_path = Temp.path!(suffix: ".jpg", basedir: dir)
    :ok = Image.write_to_file(out, out_path)

    assert_files_equal(img_path("invert_puppies.jpg"), out_path)
  end

  test "affine", %{dir: dir} do
    {:ok, im} = Image.new_from_file(img_path("puppies.jpg"))
    assert {:ok, out} = Operation.affine(im, [1, 0, 0, 0.5])

    out_path = Temp.path!(suffix: ".jpg", basedir: dir)
    :ok = Image.write_to_file(out, out_path)

    assert_files_equal(img_path("affine_puppies.jpg"), out_path)
  end

  test "gravity", %{dir: dir} do
    {:ok, im} = Image.new_from_file(img_path("puppies.jpg"))

    assert {:ok, out} =
             Operation.gravity(im, :VIPS_COMPASS_DIRECTION_CENTRE, 650, 500,
               extend: :VIPS_EXTEND_COPY
             )

    out_path = Temp.path!(suffix: ".jpg", basedir: dir)
    :ok = Image.write_to_file(out, out_path)

    assert_files_equal(img_path("gravity_puppies.jpg"), out_path)
  end

  test "conv with simple edge detection kernel", %{dir: dir} do
    {:ok, im} = Image.new_from_file(img_path("puppies.jpg"))
    {:ok, mask} = Image.new_matrix_from_array(3, 3, [[-1, -1, -1], [-1, 8, -1], [-1, -1, -1]])

    assert {:ok, out} = Operation.conv(im, mask, precision: :VIPS_PRECISION_FLOAT)

    out_path = Temp.path!(suffix: ".jpg", basedir: dir)
    :ok = Image.write_to_file(out, out_path)

    assert_files_equal(img_path("conv_puppies.jpg"), out_path)
  end

  test "additional return values", %{dir: _dir} do
    {:ok, im} = Image.new_from_file(img_path("black_on_white.jpg"))

    assert {:ok, {0.0, [x: _, y: _, "out-array": [0.0], "x-array": [_ | _], "y-array": [_ | _]]}} =
             Operation.min(im)
  end

  test "required output order", %{dir: _dir} do
    {:ok, im} = Image.new_from_file(img_path("black_on_white.jpg"))
    assert Operation.find_trim(im) == {:ok, {41, 44, 45, 45, []}}
  end

  test "operation error", %{dir: _dir} do
    {:ok, im} = Image.new_from_file(img_path("black_on_white.jpg"))

    assert Operation.affine(im, [1, 1, 1, 1]) ==
             {:error,
              "operation build: vips__transform_calc_inverse: singular or near-singular matrix"}
  end

  test "image type mis-match error", %{dir: _dir} do
    assert_raise ArgumentError, "expected Vix.Vips.Image. given: :invalid", fn ->
      Operation.invert(:invalid)
    end
  end

  test "enum parameter", %{dir: dir} do
    {:ok, im} = Image.new_from_file(img_path("black_on_white.jpg"))
    {:ok, out} = Operation.flip(im, :VIPS_DIRECTION_HORIZONTAL)

    out_path = Temp.path!(suffix: ".jpg", basedir: dir)
    :ok = Image.write_to_file(out, out_path)

    assert_files_equal(img_path("black_on_white_hflip.jpg"), out_path)
  end
end
