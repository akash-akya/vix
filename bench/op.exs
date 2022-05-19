alias Vix.Vips.Operation
alias Vix.Vips.Image
require Logger

img = Path.join(__DIR__, "../test/images/puppies.jpg")
name = Path.basename(__ENV__.file, ".exs")

Benchee.run(
  %{
    "Vix" => fn ->
      {:ok, img} = Image.new_from_file(img)

      :ok =
        Operation.resize!(img, 2)
        |> Image.write_to_file("vix.png")
    end,
    "Mogrify" => fn ->
      Mogrify.open(img)
      |> Mogrify.resize("200%")
      |> Mogrify.format("png")
      |> Mogrify.save(path: "mogrify.png")
    end
  },
  parallel: 4,
  warmup: 5,
  time: 30,
  formatters: [
    {Benchee.Formatters.HTML, file: Path.expand("output/#{name}.html", __DIR__)},
    Benchee.Formatters.Console
  ]
)
