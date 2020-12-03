defmodule Vix.MixProject do
  use Mix.Project

  def project do
    [
      app: :vix,
      version: "0.1.0",
      elixir: "~> 1.7",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: [:elixir_make] ++ Mix.compilers(),
      make_targets: ["all"],
      make_clean: ["clean"],
      deps: deps(),

      # Package
      package: package(),
      description: description(),

      # Docs
      source_url: "https://github.com/akash-akya/vix",
      homepage_url: "https://github.com/akash-akya/vix",
      docs: [
        main: "readme",
        extras: ["README.md"]
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp description do
    "NIF based bindings for Vips"
  end

  defp package do
    [
      maintainers: ["Akash Hiremath"],
      licenses: ["MIT"],
      files: ~w(lib .formatter.exs mix.exs README* LICENSE* c_src Makefile),
      links: %{
        GitHub: "https://github.com/akash-akya/vix",
        libvips: "https://libvips.github.io/libvips"
      }
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:elixir_make, "~> 0.6.2", runtime: false},
      {:ex_doc, ">= 0.0.0", only: :dev},
      {:temp, "~> 0.4", only: :test, runtime: false}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]
end
