defmodule Vix.Vips.ImageTest do
  use ExUnit.Case
  alias Vix.Vips.Image

  import Vix.Support.Images

  setup do
    Temp.track!()
    dir = Temp.mkdir!()
    {:ok, %{dir: dir}}
  end

  test "new_from_file" do
    assert {:error, 'Failed to read image'} == Image.new_from_file('invalid.jpg')
  end

  test "write_to_file", %{dir: dir} do
    path = img_path("puppies.jpg") |> to_charlist()
    {:ok, im} = Image.new_from_file(path)

    out_path = Temp.path!(suffix: ".png", basedir: dir)
    assert :ok == Image.write_to_file(im, out_path)

    stat = File.stat!(out_path)
    assert stat.size > 0 and stat.type == :regular
  end

  test "new_matrix_from_array", %{dir: _dir} do
    assert {:ok, _} =
             Image.new_matrix_from_array(3, 3, [[-1, -1, -1], [-1, 16, -1], [-1, -1, -1]])
  end

  test "get_fields", %{dir: _dir} do
    {:ok, im} = Image.new_from_file(img_path("puppies.jpg"))
    assert {:ok, fields} = Image.header_field_names(im)

    assert Enum.all?(
             [
               "vips-loader",
               "filename",
               "yres",
               "xres",
               "yoffset",
               "xoffset",
               "bands",
               "height",
               "width"
             ],
             &Enum.member?(fields, &1)
           )
  end

  test "get_header", %{dir: _dir} do
    {:ok, im} = Image.new_from_file(img_path("puppies.jpg"))
    assert {:ok, 518} = Image.header_value(im, "width")
  end

  test "get_as_string", %{dir: _dir} do
    {:ok, im} = Image.new_from_file(img_path("puppies.jpg"))

    assert {:ok, "((VipsInterpretation) VIPS_INTERPRETATION_sRGB)"} =
             Image.header_value_as_string(im, "interpretation")
  end

  test "macro generated function", %{dir: _dir} do
    {:ok, im} = Image.new_from_file(img_path("puppies.jpg"))
    assert 518 == Image.width(im)
  end
end
