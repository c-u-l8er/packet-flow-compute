# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :packetflow_chat,
  ecto_repos: [PacketflowChat.Repo],
  generators: [timestamp_type: :utc_datetime, binary_id: true]

# Configures the endpoint
config :packetflow_chat, PacketflowChatWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [json: PacketflowChatWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: PacketflowChat.PubSub,
  live_view: [signing_salt: "Vzn84pKf"]

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :packetflow_chat, PacketflowChat.Mailer, adapter: Swoosh.Adapters.Local

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Configure CORS
config :cors_plug,
  origin: ["http://localhost:5173", "http://localhost:3000"],
  max_age: 86400,
  methods: ["GET", "POST", "PUT", "DELETE", "OPTIONS"]

# Configure Clerk authentication
config :packetflow_chat,
  clerk_secret_key: System.get_env("CLERK_SECRET_KEY", "dev-secret-key"),
  clerk_issuer_url: System.get_env("CLERK_ISSUER_URL", "https://your-app.clerk.accounts.dev"),
  app_name: System.get_env("APP_NAME", "TickTickClock")

# Configure PacketFlow MCP Server
config :packet_flow, :mcp,
  server_name: "PacketFlow MCP Server",
  server_version: "1.0.0",
  port: String.to_integer(System.get_env("MCP_PORT", "8080")),
  host: System.get_env("MCP_HOST", "localhost"),
  transport: :http,
  auto_generate_tools: true,
  expose_capabilities: :all,
  tool_timeout: :timer.seconds(30),
  capabilities: %{
    tools: %{listChanged: true},
    resources: %{subscribe: true, listChanged: true}
  }

# Configure PacketFlow Actors with MCP support
config :packet_flow, :actors,
  default_timeout: :timer.minutes(30),
  max_actors_per_user: 50,
  persistence_strategy: :memory,
  cleanup_interval: :timer.minutes(5),
  mcp_enabled: true,
  mcp_timeout: :timer.seconds(30),
  default_mcp_tools: []

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
