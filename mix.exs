defmodule Uberlog.MixProject do
  use Mix.Project

  def project do
    [
      app: :uberlog,
      version: "1.0.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.7",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),

      name: "Uberlog",
      description: "Elixir Logger Backends library with various logging strategies",
      source_url: "https://github.com/PharosProduction/uberlog",
      homepage_url: "http://www.pharosproduction.com",
      docs: [main: "readme", extras: ["README.md"]]
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {Uberlog.Application, []}
    ]
  end

  defp deps do
    [
      {:gen_stage, "~> 0.14"},
      {:httpoison, "~> 1.2", override: true},
      {:jason, "~> 1.1"},
      {:optium, "~> 0.3"},
      {:backoff, "~> 1.1"}
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/PharosProduction/uberlog"},
      maintainers: ["Dmytro Nasyrov @ Pharos Production Inc."]
    ]
  end
end
