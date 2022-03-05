defmodule Vix.Vips.ForeignTest do
  use ExUnit.Case, async: true
  alias Vix.Vips.Foreign
  import Vix.Support.Images

  test "find_load_buffer" do
    path = img_path("puppies.jpg")
    assert {:ok, "VipsForeignLoadJpegBuffer"} = Foreign.find_load_buffer(File.read!(path))
  end

  test "find_save_buffer" do
    assert {:ok, "VipsForeignSaveJpegBuffer"} = Foreign.find_save_buffer("puppies.jpg")
  end

  test "find_load" do
    path = img_path("puppies.jpg")
    assert {:ok, "VipsForeignLoadJpegFile"} = Foreign.find_load(path)
  end

  test "find_save" do
    assert {:ok, "VipsForeignSaveJpegFile"} = Foreign.find_save("puppies.jpg")
  end
end
