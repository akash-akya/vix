if Code.ensure_loaded?(Kino.Render) do
  defmodule Vix.Vips.LivebookRenderTest do
    use ExUnit.Case, async: true

    alias Vix.Vips.Image

    import Vix.Support.Images

    test "Rendering livebook metadata and image" do
      Application.ensure_all_started(:kino)

      assert {:ok, %Image{ref: _ref} = image} = Image.new_from_file(img_path("puppies.jpg"))

      assert %{
               type: :tabs,
               labels: ["Image", "Attributes"],
               outputs: [
                 %{content: _, mime_type: "image/png", type: :image},
                 %{
                   export: true,
                   type: :js
                 }
               ]
             } = Kino.Render.to_livebook(image)
    end
  end
end
