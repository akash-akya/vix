defmodule Vix.Vips.SourceTest do
  use ExUnit.Case
  alias Vix.Vips.Source
  alias Vix.Vips.Image

  import Vix.Support.Images

  setup do
    Temp.track!()
    dir = Temp.mkdir!()
    {:ok, %{dir: dir}}
  end

  test "new_from_stream", %{dir: dir} do
    {:ok, source} = vips_source_from_path(img_path("puppies.jpg"))
    {:ok, im} = Image.new_from_source(source)

    out_path = Temp.path!(suffix: ".jpg", basedir: dir)
    :ok = Image.write_to_file(im, out_path)

    assert_files_equal(img_path("source_puppies.jpg"), out_path)
  end

  defp vips_source_from_path(path) do
    Source.new_from_stream(
      fn -> File.open!(path, [:raw, :binary, :read]) end,
      fn file, length ->
        case :file.read(file, length) do
          {:ok, data} ->
            {data, file}

          _ ->
            {:halt, file}
        end
      end,
      fn file -> File.close(file) end
    )
  end
end
