defmodule Vix.NifTest do
  use ExUnit.Case, async: true

  alias Vix.Nif

  import Vix.Support.Images

  test "nif_image_new_from_file" do
    path = img_path("puppies.jpg")
    {:ok, im} = Nif.nif_image_new_from_file(path)
    assert Nif.nif_g_object_type_name(im) == "VipsImage"
  end

  test "nif_image_write_area_to_binary" do
    path = img_path("puppies.jpg")
    {:ok, im} = Nif.nif_image_new_from_file(path)

    assert {:ok, {binary, 10 = width, 30 = height, 2 = bands, 0}} =
             Nif.nif_image_write_area_to_binary(im, [0, 2, 10, 30, 0, 2])

    assert IO.iodata_length(binary) == width * height * bands
  end
end
