defmodule Vix.NifTest do
  use ExUnit.Case
  alias Vix.Nif

  import Vix.Support.Images

  test "nif_image_new_from_file" do
    path = img_path("puppies.jpg") |> to_charlist()
    {:ok, im} = Nif.nif_image_new_from_file(path)
    assert 'VipsImage' == Nif.nif_g_object_type_name(im)
  end
end
