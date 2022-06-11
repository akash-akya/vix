defmodule VixBench.MixProject do
  use Mix.Project

  def project do
    [
      app: :vix_bench,
      version: "0.1.0",
      elixir: "~> 1.7",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases()
    ]
  end

  defp aliases() do
    [
      "bench.op": ["run op.exs"],
      "bench.stream": ["run stream.exs"],
      "bench.from_enum": ["run from_enum.exs"],
      "bench.to_stream": ["run to_stream.exs"],
      "bench.from_binary": ["run from_binary.exs"]
    ]
  end

  defp deps do
    [
      {:benchee, "~> 1.0"},
      {:benchee_html, "~> 1.0"},
      {:vix, "~> 0.1", path: "../", override: true},
      {:mogrify, "~> 0.8"}
    ]
  end
end
