alias Vix.Vips.Image
require Logger

img = Path.join(__DIR__, "../test/images/puppies.jpg")
name = Path.basename(__ENV__.file, ".exs")

Benchee.run(
  %{
    "write_to_file" => fn ->
      {:ok, image} = Image.new_from_file(img)
      :ok = Image.write_to_file(image, "file.png")
    end,
    "write_to_stream" => fn ->
      {:ok, image} = Image.new_from_file(img)

      :ok =
        image
        |> Image.write_to_stream(".png")
        |> Stream.into(File.stream!("stream.png"))
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
