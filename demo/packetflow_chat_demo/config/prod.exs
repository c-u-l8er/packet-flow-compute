import Config

# Configure for production environment
config :packetflow_chat_demo,
  debug_mode: false,
  enable_verbose_logging: false

# Production logging
config :logger, :console,
  level: :info,
  format: "$time [$level] $message\n"

# PacketFlow production logging
config :logger, :packetflow,
  level: :info,
  format: "$time [PacketFlow] [$level] $message\n"

# Production web server settings
config :packetflow_chat_demo, :web,
  port: String.to_integer(System.get_env("PORT") || "4000"),
  host: System.get_env("HOST") || "0.0.0.0",
  enable_cors: false

# Production chat settings
config :packetflow_chat_demo, :chat,
  default_model: System.get_env("DEFAULT_MODEL") || "gpt-3.5-turbo",
  default_temperature: String.to_float(System.get_env("DEFAULT_TEMPERATURE") || "0.7"),
  default_max_tokens: String.to_integer(System.get_env("DEFAULT_MAX_TOKENS") || "1000"),
  enable_simulation: System.get_env("ENABLE_SIMULATION") == "true"

# Production session settings
config :packetflow_chat_demo, :sessions,
  max_sessions_per_user: String.to_integer(System.get_env("MAX_SESSIONS_PER_USER") || "50"),
  session_timeout_minutes: String.to_integer(System.get_env("SESSION_TIMEOUT_MINUTES") || "120"),
  enable_session_persistence: true

# Production security settings
config :packetflow_chat_demo, :security,
  enable_rate_limiting: true,
  max_requests_per_minute: String.to_integer(System.get_env("MAX_REQUESTS_PER_MINUTE") || "100"),
  enable_capability_validation: true

# Production monitoring
config :packetflow_chat_demo, :monitoring,
  enable_health_checks: true,
  enable_metrics: true,
  metrics_port: String.to_integer(System.get_env("METRICS_PORT") || "9090")

