defmodule PacketFlow.MixProject do
  use Mix.Project

  def project do
    [
      app: :packetflow,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: "PacketFlow ADT Substrate: Intent-Context-Capability oriented algebraic data types",
      package: package(),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {PacketFlow.Application, []}
    ]
  end

  defp deps do
    [
      {:excoveralls, "~> 0.18", only: :test},
      {:ex_doc, "~> 0.29", only: :dev, runtime: false},
      {:dialyxir, "~> 1.3", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:mox, "~> 1.1", only: :test}
    ]
  end

  defp package do
    [
      maintainers: ["PacketFlow Team"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/packetflow/packetflow"},
      files: ~w(lib .formatter.exs mix.exs README.md LICENSE)
    ]
  end
end
