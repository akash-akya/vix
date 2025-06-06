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

    assert_raise ArgumentError, "Invalid band requested. Found 5", fn ->
      im[5]
    end
  end

  test "Access behaviour for Vix.Vips.Image with invalid range band" do
    {:ok, im} = Image.new_from_file(img_path("puppies.jpg"))

    assert_raise Image.Error, "Invalid band range 1..5", fn ->
      im[1..5]
    end

    assert_raise ArgumentError, "Invalid range -2..2", fn ->
      im[-5..-1]
    end
  end

  test "Access behaviour for Vix.Vips.Image with slicing and integer values" do
    {:ok, im} = Image.new_from_file(img_path("puppies.jpg"))
    assert shape(im[[]]) == shape(im)
    assert shape(im[[1]]) == {1, 389, 3}
    assert shape(im[[0..2, 5, -1]]) == {3, 1, 1}
  end

  test "Access behaviour for Vix.Vips.Image with slicing and range values" do
    {:ok, im} = Image.new_from_file(img_path("puppies.jpg"))
    assert shape(im[[]]) == shape(im)
    assert shape(im[[0..2]]) == {3, 389, 3}
    assert shape(im[[0..2, 0..3]]) == {3, 4, 3}
    assert shape(im[[0..2, 0..2, 0..1]]) == {3, 3, 2}
  end

  test "Access behaviour for Vix.Vips.Image with slicing and negative ranges" do
    {:ok, im} = Image.new_from_file(img_path("puppies.jpg"))
    assert shape(im[[-3..-1]]) == {3, 389, 3}
    assert shape(im[[-3..-1, -3..-1, -2..-1]]) == {3, 3, 2}
  end

  test "Access behaviour for Vix.Vips.Image with invalid argument" do
    {:ok, im} = Image.new_from_file(img_path("puppies.jpg"))

    assert_raise ArgumentError,
                 "Argument must be list of integers or ranges or keyword list",
                 fn -> im[[:foo]] end

    assert_raise ArgumentError,
                 "Argument must be list of integers or ranges or keyword list",
                 fn -> im[[nil, 1]] end
  end

  test "Access behaviour with invalid dimensions" do
    {:ok, im} = Image.new_from_file(img_path("puppies.jpg"))

    # Negative indices can't include 0 since that's a wrap-around
    assert_raise ArgumentError, "Invalid range -3..0", fn ->
      im[[-3..0]]
    end

    # Index larger than the image
    assert_raise ArgumentError, "Invalid range 0..1000", fn ->
      im[[0..1_000]]
    end
  end

  test "Access behaviour for Vix.Vips.Image with slicing and keyword list" do
    {:ok, im} = Image.new_from_file(img_path("puppies.jpg"))
    assert shape(im[[]]) == {518, 389, 3}
    assert shape(im[[height: 0..10]]) == {518, 11, 3}
    assert shape(im[[band: 2, height: 0..10]]) == {518, 11, 1}
    assert shape(im[[band: -2..-1]]) == {518, 389, 2}
  end

  # We can't use the 1..3//1 syntax since it fails on older
  # Elixir. So we detect when the `Range.t` has a `:step` and then
  # use Map.put/3 to place the expected value

  if range_has_step() do
    test "Access behaviour for Vix.Vips.Image with slicing and mixed positive/negative ranges" do
      {:ok, im} = Image.new_from_file(img_path("puppies.jpg"))
      assert shape(im[[Map.put(0..-1//-1, :step, 1)]]) == {518, 389, 3}

      im =
        im[
          [Map.put(0..-1//-1, :step, 1), Map.put(1..-1//-1, :step, 1), Map.put(-2..-1, :step, 1)]
        ]

      assert shape(im) == {518, 388, 2}
    end

    test "Access behaviour with invalid dimensions and invalid step" do
      {:ok, im} = Image.new_from_file(img_path("puppies.jpg"))

      # Step != 1
      assert_raise ArgumentError, "Range arguments must have a step of 1. Found 0..-3//2", fn ->
        im[[Map.put(0..-3//-1, :step, 2)]]
      end
    end

    test "Access behaviour with invalid dimensions when ranges have steps" do
      {:ok, im} = Image.new_from_file(img_path("puppies.jpg"))

      # Index not increasing
      assert_raise ArgumentError, "Range arguments must have a step of 1. Found 0..-3//-1", fn ->
        im[[0..-3//-1]]
      end
    end
  end
end
