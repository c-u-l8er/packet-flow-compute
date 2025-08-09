defmodule PacketflowChatDemo.MixProject do
  use Mix.Project

  def project do
    [
      app: :packetflow_chat_demo,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: "PacketFlow LLM Chat Demo - Showcasing PacketFlow for LLM chat applications",
      package: package()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {PacketflowChatDemo.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # PacketFlow dependency (local path for demo)
      {:packetflow, path: "../.."},

      # Phoenix LiveView for real-time web interface
      {:phoenix, "~> 1.7"},
      {:phoenix_live_view, "~> 0.20"},
      {:phoenix_live_reload, "~> 1.4", only: :dev},
      {:phoenix_html, "~> 4.0"},
      {:phoenix_ecto, "~> 4.0"},
      {:phoenix_live_dashboard, "~> 0.8", only: :dev},

      # Web framework dependencies
      {:plug, "~> 1.14"},
      {:plug_cowboy, "~> 2.6"},
      {:cowboy, "~> 2.10"},
      {:jason, "~> 1.4"},

      # HTTP client for API calls
      {:httpoison, "~> 2.0"},
      {:hackney, "~> 1.18"},

      # Database and authentication
      {:ecto_sql, "~> 3.10"},
      {:postgrex, "~> 0.17"},
      {:bcrypt_elixir, "~> 3.0"},
      {:guardian, "~> 2.3"},
      {:guardian_phoenix, "~> 2.0"},

      # Server-Sent Events for streaming
      {:event_bus, "~> 1.7"},

      # Template engine
      {:temple, "~> 0.9"},

      # Development and testing dependencies
      {:ex_doc, "~> 0.29", only: :dev, runtime: false},
      {:dialyxir, "~> 1.3", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},

      # Asset building
      {:esbuild, "~> 0.8", only: :dev},
      {:tailwind, "~> 0.2", only: :dev},

      # Internationalization
      {:gettext, "~> 0.20"}
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
