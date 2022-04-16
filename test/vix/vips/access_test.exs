defmodule Vix.Vips.AccessTest do
  use ExUnit.Case, async: true
  import Vix.Support.Images
  alias Vix.Vips.Image

  test "Access behaviour for Vix.Vipx.Image" do
    {:ok, im} = Image.new_from_file(img_path("puppies.jpg"))
    assert im[1]
  end

  test "Access behaviour for Vix.Vipx.Image with invalid band" do
    {:ok, im} = Image.new_from_file(img_path("puppies.jpg"))
    assert im[5] == nil
  end
end
