defmodule Vix.MixProject do
  use Mix.Project

  @version "0.11.0"
  @scm_url "https://github.com/akash-akya/vix"

  def project do
    [
      app: :vix,
      version: @version,
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
      source_url: @scm_url,
      homepage_url: @scm_url,
      docs: [
        main: "readme",
        source_ref: "v#{@version}",
        extras: [
          "README.md",
          "LICENSE",
          "livebooks/introduction.livemd",
          "livebooks/picture-language.livemd"
        ],
        groups_for_extras: [
          Livebooks: Path.wildcard("livebooks/*.livemd")
        ]
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp description do
    "NIF based bindings for libvips"
  end

  defp package do
    [
      maintainers: ["Akash Hiremath"],
      licenses: ["MIT"],
      files:
        ~w(lib .formatter.exs mix.exs README* LICENSE* Makefile c_src/Makefile c_src/*.{h,c} c_src/g_object/*.{h,c}),
      links: %{
        GitHub: @scm_url,
        libvips: "https://libvips.github.io/libvips"
      }
    ]
  end

  defp deps do
    [
      {:elixir_make, "~> 0.6", runtime: false},
      {:ex_doc, ">= 0.0.0", only: :dev},
      {:temp, "~> 0.4", only: :test, runtime: false}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]
end
