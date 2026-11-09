defmodule Vix.VipsBlockTest do
  # Not async: blocking is global
  use ExUnit.Case, async: false

  alias Vix.Vips
  alias Vix.Vips.Image
  alias Vix.Vips.Operation

  import Vix.Support.Images

  @svg ~s(<svg xmlns="http://www.w3.org/2000/svg" width="10" height="10"/>)

  setup do
    on_exit(fn -> Vips.operation_block_set("VipsForeignLoad", false) end)
  end

  test "operation_block_set/2" do
    :ok = Vips.operation_block_set("pngload", true)
    assert "pngload" in Vips.blocked_operations()
    assert {:error, _} = Operation.pngload(img_path("gradient.png"))

    :ok = Vips.operation_block_set("pngload", false)
    assert {:ok, _} = Operation.pngload(img_path("gradient.png"))

    assert {:error, "Unknown operation"} = Vips.operation_block_set("NoSuchOperation", true)
  end

  test "allow_loaders/1" do
    :ok = Vips.allow_loaders([:jpeg])
    assert {:ok, _} = Image.new_from_file(img_path("puppies.jpg"))
    assert {:error, _} = Image.new_from_file(img_path("gradient.png"))

    :ok = Vips.allow_loaders([:png])
    assert {:ok, _} = Image.new_from_file(img_path("gradient.png"))

    assert {:error, "Unknown loader formats: [:avif]"} = Vips.allow_loaders([:avif])
  end

  test "loader_formats/0" do
    assert ".jpg" in Vips.loader_formats().jpeg
  end

  test "block_untrusted_set/1" do
    on_exit(fn -> Vips.block_untrusted_set(false) end)

    :ok = Vips.block_untrusted_set(true)
    assert {:error, _} = Operation.svgload_buffer(@svg)

    :ok = Vips.block_untrusted_set(false)
    assert {:ok, _} = Operation.svgload_buffer(@svg)
  end
end
