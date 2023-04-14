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
    assert {:ok, img} =
             Image.new_matrix_from_array(2, 2, [
               [-1, -1],
               [0, 16]
             ])

    assert %{width: 2, height: 2} = Image.headers(img)

    assert {:ok,
            <<
              (<<-1::little-float, -1::little-float>>),
              (<<0::little-float, 16::little-float>>)
            >>} = Image.write_to_binary(img)
  end

  describe "new_from_list" do
    test "when argument is range", %{dir: _dir} do
      assert {:ok, img} = Image.new_from_list(0..2)

      assert %{width: 3, height: 1} = Image.headers(img)

      assert {:ok, <<0::little-float, 1::little-float, 2::little-float>>} =
               Image.write_to_binary(img)
    end

    test "when argument is range within list", %{dir: _dir} do
      assert {:ok, img} = Image.new_from_list([0..1, -1..0])

      assert %{width: 2, height: 2} = Image.headers(img)

      assert {:ok,
              <<
                (<<0::little-float, 1::little-float>>),
                (<<-1::little-float, 0::little-float>>)
              >>} = Image.write_to_binary(img)
    end

    test "when list is 1D", %{dir: _dir} do
      assert {:ok, img} = Image.new_from_list([0, 1, 2])

      assert %{width: 3, height: 1} = Image.headers(img)

      assert {:ok, <<0::little-float, 1::little-float, 2::little-float>>} =
               Image.write_to_binary(img)
    end

    test "when list is 2D", %{dir: _dir} do
      assert {:ok, img} =
               Image.new_from_list([
                 [1, 2, 3],
                 [-1, -2, -3]
               ])

      assert %{width: 3, height: 2} = Image.headers(img)

      assert {:ok,
              <<
                (<<1::little-float, 2::little-float, 3::little-float>>),
                (<<-1::little-float, -2::little-float, -3::little-float>>)
              >>} = Image.write_to_binary(img)
    end
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

  test "headers", %{dir: _dir} do
    {:ok, im} = Image.new_from_file(img_path("puppies.jpg"))

    assert %{
             bands: 3,
             coding: :VIPS_CODING_NONE,
             filename: _filename,
             format: :VIPS_FORMAT_UCHAR,
             height: 389,
             interpretation: :VIPS_INTERPRETATION_sRGB,
             mode: nil,
             "n-pages": nil,
             offset: nil,
             orientation: 1,
             "page-height": nil,
             scale: nil,
             width: 518,
             xoffset: 0,
             xres: 2.834645669291339,
             yoffset: 0,
             yres: 2.834645669291339
           } = Image.headers(im)
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

  test "new_from_enum", %{dir: dir} do
    {:ok, image} =
      File.stream!(img_path("puppies.jpg"), [], 1024)
      |> Image.new_from_enum("")

    out_path = Temp.path!(suffix: ".png", basedir: dir)
    :ok = Image.write_to_file(image, out_path)

    stat = File.stat!(out_path)
    assert stat.size > 0 and stat.type == :regular
  end

  test "new_from_enum invalid data write" do
    {:error, "Failed to create image from VipsSource"} = Image.new_from_enum(1..100)
  end

  test "premature end of new_from_enum" do
    {:error, "Failed to create image from VipsSource"} =
      File.stream!(img_path("puppies.jpg"), [], 100)
      |> Stream.take(1)
      |> Image.new_from_enum("")
  end

  test "write_to_stream", %{dir: dir} do
    {:ok, im} = Image.new_from_file(img_path("puppies.jpg"))

    out_path = Temp.path!(suffix: ".png", basedir: dir)

    :ok =
      Image.write_to_stream(im, ".png")
      |> Stream.into(File.stream!(out_path))
      |> Stream.run()

    stat = File.stat!(out_path)
    assert stat.size > 0 and stat.type == :regular
  end

  test "write_to_stream with invalid suffix", %{dir: dir} do
    {:ok, im} = Image.new_from_file(img_path("puppies.jpg"))

    out_path = Temp.path!(suffix: ".png", basedir: dir)

    assert_raise Vix.Vips.Image.Error, fn ->
      Image.write_to_stream(im, ".invalid")
      |> Stream.into(File.stream!(out_path))
      |> Stream.run()
    end
  end

  test "new_from_binary", %{dir: dir} do
    {:ok, im} = Image.new_from_file(img_path("puppies.jpg"))
    # same image in raw pixel format
    bin = File.read!(img_path("puppies.raw"))

    assert {:ok, image} =
             Image.new_from_binary(
               bin,
               Image.width(im),
               Image.height(im),
               Image.bands(im),
               Image.format(im)
             )

    out_path = Temp.path!(suffix: ".png", basedir: dir)
    :ok = Image.write_to_file(image, out_path)

    stat = File.stat!(out_path)
    assert stat.size > 0 and stat.type == :regular
  end

  test "write_to_binary" do
    {:ok, im} = Image.new_from_file(img_path("black.jpg"))
    assert {:ok, bin} = Image.write_to_binary(im)

    expected_bin_size = Image.width(im) * Image.height(im) * Image.bands(im)

    assert IO.iodata_length(bin) == expected_bin_size
    assert :binary.copy(<<0>>, expected_bin_size) == bin
  end

  test "write_to_tensor" do
    {:ok, im} = Image.new_from_file(img_path("black.jpg"))
    assert {:ok, %Vix.Tensor{} = tensor} = Image.write_to_tensor(im)

    assert tensor.shape == {Image.width(im), Image.height(im), Image.bands(im)}

    expected_bin_size = Image.width(im) * Image.height(im) * Image.bands(im)
    assert tensor.data == :binary.copy(<<0>>, expected_bin_size)
  end

  test "new_from_binary and write_to_binary endianness handling", %{dir: dir} do
    {width, height} = {125, 125}

    # generate a test pixel data in native endianness
    bin =
      for y <- 1..height, into: <<>> do
        for x <- 1..width, into: <<>> do
          <<y * 2.0::native-float-32, 0::native-float-32, x * 2.0::native-float-32>>
        end
      end

    {:ok, img} = Image.new_from_binary(bin, width, height, 3, :VIPS_FORMAT_FLOAT)

    # endianness file read from disk and from memory must be same
    {:ok, expected} = Image.new_from_file(img_path("gradient.png"))
    assert_images_equal(expected, img)

    out_path = Temp.path!(suffix: ".v", basedir: dir)
    :ok = Image.write_to_file(img, out_path)

    {:ok, vimg} = Image.new_from_file(out_path)
    {:ok, vbin} = Image.write_to_binary(vimg)

    # endianness file written to disk and memory must be same
    assert bin == vbin
  end
end
