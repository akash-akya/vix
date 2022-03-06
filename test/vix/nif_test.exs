defmodule Vix.NifTest do
  use ExUnit.Case, async: true

  alias Vix.Nif

  import Vix.Support.Images

  test "nif_image_new_from_file" do
    path = img_path("puppies.jpg")
    {:ok, im} = Nif.nif_image_new_from_file(path)
    assert Nif.nif_g_object_type_name(im) == "VipsImage"
  end
end
