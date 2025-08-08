import Config

# Configure for development environment
config :packetflow_chat_demo,
  debug_mode: true,
  enable_verbose_logging: true

# Development-specific logging
config :logger, :console,
  level: :debug,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id, :user_id, :session_id]

# PacketFlow development logging
config :logger, :packetflow,
  level: :debug,
  format: "$time [PacketFlow] [$level] $message\n"

# Enable detailed error reporting
config :logger, :error,
  level: :debug,
  format: "$time [$level] $message\n$stacktrace\n"

# Development web server settings
config :packetflow_chat_demo, :web,
  port: 4000,
  host: "localhost",
  enable_cors: true

# Development chat settings
config :packetflow_chat_demo, :chat,
  default_model: "gpt-3.5-turbo",
  default_temperature: 0.7,
  default_max_tokens: 1000,
  enable_simulation: true

# Development session settings
config :packetflow_chat_demo, :sessions,
  max_sessions_per_user: 10,
  session_timeout_minutes: 60,
  enable_session_persistence: true

