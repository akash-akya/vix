defmodule Vix.Vips.ImageTest do
  use ExUnit.Case
  alias Vix.Vips.Image

  import Vix.Support.Images

  setup do
    Temp.track!()
    dir = Temp.mkdir!()
    {:ok, %{dir: dir}}
  end

  test "new_from_file" do
    assert {:error, 'Failed to read image'} == Image.new_from_file('invalid.jpg')
  end

  test "write_to_file", %{dir: dir} do
    path = img_path("puppies.jpg") |> to_charlist()
    {:ok, im} = Image.new_from_file(path)

    out_path = Temp.path!(suffix: ".png", basedir: dir)
    assert :ok == Image.write_to_file(im, out_path)

    stat = File.stat!(out_path)
    assert stat.size > 0 and stat.type == :regular
  end
end
