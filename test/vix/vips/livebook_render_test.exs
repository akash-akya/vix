if Code.ensure_loaded?(Kino.Render) do
  defmodule Vix.Vips.LivebookRenderTest do
    use ExUnit.Case, async: true

    alias Vix.Vips.Image

    import Vix.Support.Images

    test "Rendering livebook metadata and image" do
      Application.ensure_all_started(:kino)

      assert {:ok, %Image{ref: _ref} = image} = Image.new_from_file(img_path("puppies.jpg"))

      assert {
               :tabs,
               [
                 {:image, _, "image/png"},
                 {:js,
                  %{
                    export: nil,
                    js_view: %{assets: %{archive_path: _, hash: _, js_path: "main.js"}, pid: _}
                  }}
               ],
               %{labels: ["Image", "Attributes"]}
             } = Kino.Render.to_livebook(image)
    end
  end
end
