defmodule Vix.Vips.AccessTest do
  use ExUnit.Case, async: true
  import Vix.Support.Images
  alias Vix.Vips.Image

  test "Access behaviour for Vix.Vipx.Image for an integer" do
    {:ok, im} = Image.new_from_file(img_path("puppies.jpg"))
    assert im[1]
  end

  test "Access behaviour for Vix.Vipx.Image for a range" do
    {:ok, im} = Image.new_from_file(img_path("puppies.jpg"))
    assert im[1..2]
  end

  test "Access behaviour for Vix.Vipx.Image with invalid integer band" do
    {:ok, im} = Image.new_from_file(img_path("puppies.jpg"))
    assert im[5] == nil
  end

  test "Access behaviour for Vix.Vipx.Image with invalid range band" do
    {:ok, im} = Image.new_from_file(img_path("puppies.jpg"))
    assert im[1..5] == nil
    assert im[-5..-1] == nil
    assert im[-5..-1//2] == nil
  end
end
