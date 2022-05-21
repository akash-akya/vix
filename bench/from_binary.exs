alias Vix.Vips.Image
require Logger

jpg_img_path = Path.join(__DIR__, "../test/images/puppies.jpg")
raw_img_path = Path.join(__DIR__, "../test/images/puppies.raw")
name = Path.basename(__ENV__.file, ".exs")

{:ok, im} = Image.new_from_file(jpg_img_path)
bin = File.read!(raw_img_path)

Benchee.run(
  %{
    "from_binary" => fn ->
      {:ok, image} =
        Image.new_from_binary(
          bin,
          Image.width(im),
          Image.height(im),
          Image.bands(im),
          Image.format(im)
        )

      :ok = Image.write_to_file(image, "from_binary.png")
    end
  },
  parallel: 4,
  warmup: 2,
  time: 20,
  formatters: [
    {Benchee.Formatters.HTML, file: Path.expand("output/#{name}.html", __DIR__)},
    Benchee.Formatters.Console
  ]
)
