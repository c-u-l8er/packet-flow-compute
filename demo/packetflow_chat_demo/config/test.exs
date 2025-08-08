import Config

# Configure for test environment
config :packetflow_chat_demo,
  debug_mode: false,
  enable_verbose_logging: false

# Test-specific logging (minimal)
config :logger, :console,
  level: :warn,
  format: "$time [$level] $message\n"

# PacketFlow test logging (minimal)
config :logger, :packetflow,
  level: :warn,
  format: "$time [PacketFlow] [$level] $message\n"

# Test web server settings
config :packetflow_chat_demo, :web,
  port: 4001,  # Different port for tests
  host: "localhost",
  enable_cors: false

# Test chat settings
config :packetflow_chat_demo, :chat,
  default_model: "test-model",
  default_temperature: 0.5,
  default_max_tokens: 100,
  enable_simulation: true

# Test session settings
config :packetflow_chat_demo, :sessions,
  max_sessions_per_user: 5,
  session_timeout_minutes: 10,
  enable_session_persistence: false  # Don't persist in tests

