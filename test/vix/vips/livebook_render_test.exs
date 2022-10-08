defmodule Vix.Vips.LivebookRenderTest do
  use ExUnit.Case, async: true

  alias Vix.Vips.Image

  import Vix.Support.Images

  test "Rendering livebook metadata and image" do
    Application.ensure_all_started(:kino)

    assert {:ok, %Image{ref: _ref} = image} = Image.new_from_file(img_path("puppies.jpg"))
    assert {:tabs,
       [
         {:js,
          %{
            export: nil,
            js_view: %{
              assets: %{
                archive_path: _,
                hash: _,
                js_path: "main.js"
              },
              pid: _,
              ref: _
            }
          }},
         {:image, _, "image/png"}
       ], %{labels: ["Attributes", "Image"]}} = Kino.Render.to_livebook(image)
  end

end