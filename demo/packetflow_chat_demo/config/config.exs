# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
import Config

# Configure your application
config :packetflow_chat_demo,
  namespace: PacketflowChatDemo,
  ecto_repos: [PacketflowChatDemo.Repo],
  generators: [timestamp_type: :utc_datetime],
  # OpenAI API configuration - will be overridden by environment variables
  openai_api_key: nil

# Configure the database (will be overridden by environment-specific configs)
config :packetflow_chat_demo, PacketflowChatDemo.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "packetflow_chat_demo_dev",
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

# Configure Guardian for authentication
config :packetflow_chat_demo, PacketflowChatDemo.Guardian,
  issuer: "packetflow_chat_demo",
  secret_key: "your-secret-key-here-replace-in-production"

# Configure your endpoint
config :packetflow_chat_demo, PacketflowChatDemoWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Phoenix.Endpoint.Cowboy2Adapter,
  render_errors: [
    formats: [html: PacketflowChatDemoWeb.ErrorHTML, json: PacketflowChatDemoWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: PacketflowChatDemo.PubSub,
  live_view: [signing_salt: "your-signing-salt"]

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.17.11",
  default: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "3.4.0",
  default: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
