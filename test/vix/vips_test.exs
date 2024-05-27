defmodule Vix.VipsTest do
  use ExUnit.Case, async: true

  alias Vix.Vips
  alias Vix.Vips.Image

  import Vix.Support.Images

  test "tracked_get_mem/0" do
    {:ok, im} = Image.new_from_file(img_path("puppies.jpg"))
    {:ok, _bin} = Image.write_to_buffer(im, ".png")

    usage = Vips.tracked_get_mem()
    assert is_integer(usage) && usage > 0
  end

  test "tracked_get_mem_highwater/0" do
    {:ok, im} = Image.new_from_file(img_path("puppies.jpg"))
    {:ok, _bin} = Image.write_to_buffer(im, ".png")

    usage = Vips.tracked_get_mem_highwater()
    assert is_integer(usage) && usage > 0
  end
end
