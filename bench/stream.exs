alias Vix.Vips.Image
require Logger

img = Path.join(__DIR__, "../test/images/puppies.jpg")
name = Path.basename(__ENV__.file, ".exs")

Benchee.run(
  %{
    "from enum" => fn ->
      {:ok, image} =
        File.stream!(img, [], 1024 * 10)
        |> Image.new_from_enum()

      :ok =
        image
        |> Image.write_to_file("from_enum.png")
    end,
    "to enum" => fn ->
      {:ok, image} = Image.new_from_file(img)

      :ok =
        image
        |> Image.write_to_stream(".png")
        |> Stream.into(File.stream!("to_enum.png"))
        |> Stream.run()
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
