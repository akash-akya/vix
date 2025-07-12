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

  test "find_load_source" do
    bin = File.read!(img_path("puppies.jpg"))

    assert {pipe, source} = Vix.SourcePipe.new()
    assert :ok = Vix.SourcePipe.write(pipe, bin)
    assert :ok = Vix.SourcePipe.stop(pipe)

    assert {:ok, "VipsForeignLoadJpegSource"} = Foreign.find_load_source(source)
  end

  test "find_save_target" do
    assert {:ok, "VipsForeignSaveJpegTarget"} = Foreign.find_save_target(".jpg")
    assert {:error, "Failed to find saver for the target"} = Foreign.find_save_target(".pdf")
    assert {:error, "Failed to find saver for the target"} = Foreign.find_save_target(".tiff")
  end
end
