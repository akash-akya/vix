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
    assert :VIPS_INTERPRETATION_sRGB == Image.interpretation(im)
  end

  test "write image to buffer", %{dir: _dir} do
    {:ok, im} = Image.new_from_file(img_path("puppies.jpg"))
    {:ok, _bin} = Image.write_to_buffer(im, ".jpg[Q=90]")
  end

  test "display" do
    {:ok, io_device} = StringIO.open("")

    {:ok, im} = Image.new_from_file(img_path("puppies.jpg"))
    assert ^im = Image.display(im, io_device: io_device)

    {:ok, {"", image_data}} = StringIO.close(io_device)

    assert_output_to_terminal("unnamed.jpg", image_data)
  end

  test "display options" do
    {:ok, io_device} = StringIO.open("")

    {:ok, im} = Image.new_from_file(img_path("puppies.jpg"))
    im = Vix.Vips.Operation.invert!(im)

    assert ^im = Image.display(im, io_device: io_device, label: "cute_puppies", suffix: ".png")

    {:ok, {"", image_data}} = StringIO.close(io_device)

    assert_output_to_terminal("cute_puppies.png", image_data)
  end

  defp assert_output_to_terminal(expected_name, image_data) do
    assert "\e]1337;File=" <> data = image_data
    [args, image_data] = String.split(data, ":", parts: 2)

    args =
      String.split(args, ";")
      |> Map.new(fn kv ->
        [key, value] = String.split(kv, "=", parts: 2)
        {key, value}
      end)

    assert %{"name" => encoded_name, "size" => size, "inline" => "1"} = args

    assert expected_name == Base.decode64!(encoded_name)
    assert {size, ""} = Integer.parse(size)

    assert <<_::binary-size(size), "\a">> = image_data
  end
end
