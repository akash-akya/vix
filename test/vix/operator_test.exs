defmodule Vix.OperatorTest do
  use ExUnit.Case, async: true
  use Vix.Operator

  import Vix.Support.Images

  alias Vix.Vips.Image
  alias Vix.Vips.Operation

  doctest Vix.Operator

  describe "+/2" do
    test "when both arguments are image" do
      black = Operation.black!(10, 10, bands: 3)
      grey = Operation.linear!(black, [1], [125])

      out = black + grey

      assert_images_equal(out, grey)
    end

    test "when first argument is image and second argument is list" do
      black = Operation.black!(10, 10, bands: 3)

      expected = Operation.linear!(black, [1], [0, 125, 0])
      out = black + [0, 125, 0]

      assert_images_equal(out, expected)
    end

    test "when first argument is a list and second argument is image" do
      black = Operation.black!(10, 10, bands: 3)

      expected = Operation.linear!(black, [1], [0, 125, 0])
      out = [0, 125, 0] + black

      assert_images_equal(out, expected)
    end

    test "when argument is invalid" do
      black = Operation.black!(10, 10, bands: 3)

      assert_raise ArgumentError, "list elements must be a number, got: [nil]", fn ->
        black + [nil]
      end
    end

    test "when both arguments are numbers" do
      assert 1 + 1 == 2
    end
  end

  describe "*/2" do
    test "when both arguments are image" do
      black = Operation.black!(10, 10, bands: 3)
      img = Operation.linear!(black, [1], [2])

      out = img * img

      expected = Operation.linear!(black, [1], [4])
      assert_images_equal(out, expected)
    end

    test "when first argument is image and second argument is list" do
      black = Operation.black!(10, 10, bands: 3)
      img = Operation.linear!(black, [1], [2])

      out = img * [1, 2, 1]

      # [2, 2, 2] * [1, 2, 1] = [2, 4, 2]
      expected = Operation.linear!(black, [1], [2, 4, 2])
      assert_images_equal(out, expected)
    end

    test "when first argument is a list and second argument is image" do
      black = Operation.black!(10, 10, bands: 3)
      img = Operation.linear!(black, [1], [2])

      out = [1, 2, 1] * img

      # [1, 2, 1] * [2, 2, 2] = [2, 4, 2]
      expected = Operation.linear!(black, [1], [2, 4, 2])
      assert_images_equal(out, expected)
    end

    test "when both arguments are numbers" do
      assert 1 * 2 == 2
    end
  end

  describe "-/2" do
    test "when both arguments are image" do
      black = Operation.black!(10, 10, bands: 3)
      grey = Operation.linear!(black, [1], [125])

      # credo:disable-for-next-line
      out = grey - grey

      assert_images_equal(out, black)
    end

    test "when first argument is image and second argument is list" do
      black = Operation.black!(10, 10, bands: 3)
      grey = Operation.linear!(black, [1], [125])

      expected = Operation.linear!(grey, [1], [0, -125, 0])
      out = grey - [0, 125, 0]

      assert_images_equal(out, expected)
    end

    test "when first argument is a list and second argument is image" do
      black = Operation.black!(10, 10, bands: 3)
      grey = Operation.linear!(black, [1], [125])

      expected = Operation.linear!(grey, [-1], [255, 255, 255])
      out = [255, 255, 255] - grey

      assert_images_equal(out, expected)
    end

    test "when both arguments are numbers" do
      assert 1 - 1 == 0
    end
  end

  describe "//2" do
    test "when both arguments are image" do
      black = Operation.black!(10, 10, bands: 3)
      grey = Operation.linear!(black, [1], [4])

      # credo:disable-for-next-line
      out = grey / grey

      expected = Operation.linear!(black, [1], [1])
      assert_images_equal(out, expected)
    end

    test "when first argument is image and second argument is list" do
      black = Operation.black!(10, 10, bands: 3)
      img = Operation.linear!(black, [1], [4])

      out = img / [1, 2, 1]

      # [4, 4, 4] / [1, 2, 1] = [4, 2, 4]
      expected = Operation.linear!(black, [1], [4, 2, 4])
      assert_images_equal(out, expected)
    end

    test "when first argument is a list and second argument is image" do
      black = Operation.black!(10, 10, bands: 3)
      img = Operation.linear!(black, [1], [2])

      out = [4, 8, 4] / img

      # [4, 8, 4] / [2, 2, 2] = [2, 4, 2]
      expected = Operation.linear!(black, [1], [2, 4, 2])
      assert_images_equal(out, expected)
    end

    test "when both arguments are numbers" do
      assert 4 / 2 == 2
    end
  end

  describe "**/2" do
    test "when both arguments are image" do
      black = Operation.black!(10, 10, bands: 3)
      img = Operation.linear!(black, [1], [4])

      out = img ** img

      expected_pow = 4 ** 4
      expected = Operation.linear!(black, [1], [expected_pow])
      assert_images_equal(out, expected)
    end

    test "when first argument is image and second argument is list" do
      black = Operation.black!(10, 10, bands: 3)
      img = Operation.linear!(black, [1], [3])

      out = img ** [1, 2, 1]

      # [3, 3, 3] ** [1, 2, 1] = [3, 9, 3]
      expected = Operation.linear!(black, [1], [3, 9, 3])
      assert_images_equal(out, expected)
    end

    test "when first argument is a list and second argument is image" do
      black = Operation.black!(10, 10, bands: 3)
      img = Operation.linear!(black, [1], [3])

      out = [1, 2, 1] ** img

      # [1, 2, 1] ** [3, 3, 3] = [1, 8, 1]
      expected = Operation.linear!(black, [1], [1, 8, 1])
      assert_images_equal(out, expected)
    end

    test "when both arguments are numbers" do
      assert 3 ** 2 == 9
    end
  end
end
