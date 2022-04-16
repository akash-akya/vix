defmodule Vix.Vips.ImageTest do
  use ExUnit.Case, async: true

  alias Vix.Vips.Image
  alias Vix.Vips.MutableImage

  import Vix.Support.Images

  setup do
    Temp.track!()
    dir = Temp.mkdir!()
    {:ok, %{dir: dir}}
  end

  test "new_from_file" do
    assert {:error, "Failed to read image"} == Image.new_from_file("invalid.jpg")

    assert {:ok, %Image{ref: ref}} = Image.new_from_file(img_path("puppies.jpg"))
    assert is_reference(ref)
  end

  test "new_from_buffer", %{dir: dir} do
    assert {:error, "Failed to find load buffer"} == Image.new_from_buffer(<<>>)

    path = img_path("puppies.jpg")

    assert {:ok, img_from_buf} = Image.new_from_buffer(File.read!(path))
    img_buf_out_path = Temp.path!(suffix: ".png", basedir: dir)
    assert :ok == Image.write_to_file(img_from_buf, img_buf_out_path)

    {:ok, img_from_file} = Image.new_from_file(path)
    img_file_out_path = Temp.path!(suffix: ".png", basedir: dir)
    assert :ok == Image.write_to_file(img_from_file, img_file_out_path)

    assert File.read!(img_buf_out_path) == File.read!(img_file_out_path)
  end

  test "write_to_file", %{dir: dir} do
    path = img_path("puppies.jpg")

    {:ok, %Image{ref: ref} = im} = Image.new_from_file(path)
    assert is_reference(ref)

    out_path = Temp.path!(suffix: ".png", basedir: dir)
    assert :ok == Image.write_to_file(im, out_path)

    stat = File.stat!(out_path)
    assert stat.size > 0 and stat.type == :regular
  end

  test "new_matrix_from_array", %{dir: _dir} do
    assert {:ok, _} =
             Image.new_matrix_from_array(3, 3, [[-1, -1, -1], [-1, 16, -1], [-1, -1, -1]])
  end

  test "mutate", %{dir: _dir} do
    {:ok, im} = Image.new_from_file(img_path("puppies.jpg"))

    {:ok, updated_image} =
      Image.mutate(im, fn mut_image ->
        :ok = MutableImage.update(mut_image, "orientation", 0)
        :ok = MutableImage.set(mut_image, "new-field", :gint, 0)
      end)

    assert {:ok, 0} = Image.header_value(updated_image, "orientation")
    assert {:ok, 0} = Image.header_value(updated_image, "new-field")
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

  test "get_header binary", %{dir: _dir} do
    {:ok, im} = Image.new_from_file(img_path("puppies.jpg"))
    assert {:ok, <<_::binary>>} = Image.header_value(im, "exif-data")
  end

  test "get_as_string", %{dir: _dir} do
    {:ok, im} = Image.new_from_file(img_path("puppies.jpg"))

    assert {:ok, "((VipsInterpretation) VIPS_INTERPRETATION_sRGB)"} =
             Image.header_value_as_string(im, "interpretation")
  end

  test "macro generated function", %{dir: _dir} do
    {:ok, im} = Image.new_from_file(img_path("puppies.jpg"))
    assert 518 == Image.width(im)
    assert :VIPS_INTERPRETATION_sRGB == Image.interpretation(im)

    {:ok, im} = Image.new_from_file(img_path("boats.tif"))
    assert 2 == Image.n_pages(im)
  end

  test "write image to buffer", %{dir: _dir} do
    {:ok, im} = Image.new_from_file(img_path("puppies.jpg"))
    {:ok, _bin} = Image.write_to_buffer(im, ".jpg[Q=90]")
  end

  test "new image from other image", %{dir: _dir} do
    {:ok, im} = Image.new_from_file(img_path("puppies.jpg"))
    {:ok, new_im} = Image.new_from_image(im, [250])

    assert Image.width(im) == Image.width(new_im)
    assert Image.height(im) == Image.height(new_im)
    assert Image.bands(new_im) == 1
  end

  test "image has an alpha band", %{dir: _dir} do
    {:ok, im} = Image.new_from_file(img_path("puppies.jpg"))
    refute Image.has_alpha?(im)

    {:ok, im} = Image.new_from_file(img_path("alpha_band.png"))
    assert Image.has_alpha?(im)
  end
end
