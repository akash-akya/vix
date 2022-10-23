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
  end

  test "Access behaviour for Vix.Vipx.Image with slicing" do
    {:ok, im} = Image.new_from_file(img_path("puppies.jpg"))
    assert shape(im[[:all, :all]]) == shape(im)
    assert shape(im[[:all, :all, :all]]) == shape(im)
    assert shape(im[[0..2, :all, :all]]) == {3, 389, 3}
    assert shape(im[[0..2, 0..2, 0..1]]) == {3, 3, 2}
  end

  test "Access behaviour for Vix.Vipx.Image with slicing and negative ranges" do
    {:ok, im} = Image.new_from_file(img_path("puppies.jpg"))
    assert shape(im[[-3..-1, :all, :all]]) == {3, 389, 3}
    assert shape(im[[-3..-1, -3..-1, -2..-1]]) == {3, 3, 2}
  end

  @tag :range_with_step
  test "Access behaviour for Vix.Vipx.Image with slicing and mixed positive/negative ranges" do
    {:ok, im} = Image.new_from_file(img_path("puppies.jpg"))
    assert shape(im[[0..-1//1, :all, :all]]) == {518, 389, 3}
    assert shape(im[[0..-1//1, 1..-1//1, -2..-1//1]]) == {518, 388, 2}
  end

  test "Access behaviour with invalid dimensions" do
    {:ok, im} = Image.new_from_file(img_path("puppies.jpg"))

    # Negative indicies can't include 0 since thats a wrap-around
    assert im[[-3..0, :all, :all]] == nil

    # Index larger than the image
    assert im[[0..1_000, :all, :all]] == nil

    # Index not increasing
    assert im[[0..-3, :all, :all]] == nil
  end

  @tag :range_with_step
  test "Access behaviour with invalid dimensions and invalid step" do
    {:ok, im} = Image.new_from_file(img_path("puppies.jpg"))

    # Step != 1
    assert im[[0..-3//2, :all, :all]] == nil
  end
end
