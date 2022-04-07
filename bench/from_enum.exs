alias Vix.Vips.Image
require Logger

img = Path.join(__DIR__, "../test/images/puppies.jpg")
name = Path.basename(__ENV__.file, ".exs")

Benchee.run(
  %{
    "from_file" => fn ->
      {:ok, image} = Image.new_from_file(img)
      :ok = Image.write_to_file(image, "file.png")
    end,
    "from_enum" => fn ->
      {:ok, image} =
        File.stream!(img, [], 1024 * 10)
        |> Image.new_from_enum()

      :ok = Image.write_to_file(image, "enum.png")
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
