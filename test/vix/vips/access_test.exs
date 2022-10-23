defmodule Vix.Vips.AccessTest do
  use ExUnit.Case, async: true
  import Vix.Support.Images
  alias Vix.Vips.Image

  test "Access behaviour for Vix.Vips.Image for an integer retrieves a band" do
    {:ok, im} = Image.new_from_file(img_path("puppies.jpg"))
    assert im[1]
  end

  test "Access behaviour for Vix.Vips.Image for a range retrieves a range of bands" do
    {:ok, im} = Image.new_from_file(img_path("puppies.jpg"))
    assert im[1..2]
  end

  test "Access behaviour for Vix.Vips.Image with invalid integer band" do
    {:ok, im} = Image.new_from_file(img_path("puppies.jpg"))
    assert im[5] == nil
  end

  test "Access behaviour for Vix.Vips.Image with invalid range band" do
    {:ok, im} = Image.new_from_file(img_path("puppies.jpg"))
    assert im[1..5] == nil
    assert im[-5..-1] == nil
  end

  test "Access behaviour for Vix.Vips.Image with slicing" do
    {:ok, im} = Image.new_from_file(img_path("puppies.jpg"))
    assert shape(im[[:all, :all]]) == shape(im)
    assert shape(im[[:all, :all, :all]]) == shape(im)
    assert shape(im[[0..2, :all, :all]]) == {3, 389, 3}
    assert shape(im[[0..2, 0..2, 0..1]]) == {3, 3, 2}
  end

  test "Access behaviour for Vix.Vips.Image with slicing and negative ranges" do
    {:ok, im} = Image.new_from_file(img_path("puppies.jpg"))
    assert shape(im[[-3..-1, :all, :all]]) == {3, 389, 3}
    assert shape(im[[-3..-1, -3..-1, -2..-1]]) == {3, 3, 2}
  end

  test "Access behaviour with invalid dimensions" do
    {:ok, im} = Image.new_from_file(img_path("puppies.jpg"))

    # Negative indicies can't include 0 since thats a wrap-around
    assert im[[-3..0, :all, :all]] == nil

    # Index larger than the image
    assert im[[0..1_000, :all, :all]] == nil
  end

  # We can't use the 1..3//1 syntax since it fails on older
  # Elixir. So we detect when the `Range.t` has a `:step` and then
  # use Map.put/3 to place the expected value

  if range_has_step() do
    test "Access behaviour for Vix.Vips.Image with slicing and mixed positive/negative ranges" do
      {:ok, im} = Image.new_from_file(img_path("puppies.jpg"))
      assert shape(im[[Map.put(0..-1, :step, 1), :all, :all]]) == {518, 389, 3}

      im = im[[Map.put(0..-1, :step, 1), Map.put(1..-1, :step, 1), Map.put(-2..-1, :step, 1)]]
      assert shape(im) == {518, 388, 2}
    end

    test "Access behaviour with invalid dimensions and invalid step" do
      {:ok, im} = Image.new_from_file(img_path("puppies.jpg"))

      # Step != 1
      assert im[[Map.put(0..-3, :step, 2), :all, :all]] == nil
    end

    test "Access behaviour with invalid dimensions when ranges have steps" do
      {:ok, im} = Image.new_from_file(img_path("puppies.jpg"))

      # Index not increasing
      assert im[[0..-3, :all, :all]] == nil
    end
  end
end
