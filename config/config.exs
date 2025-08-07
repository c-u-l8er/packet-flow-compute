import Config

# Configure the application
config :packetflow,
  validate_capabilities: true,
  enable_registry: true,
  log_level: :info

# Configure the test environment
config :packetflow,
  validate_capabilities: false,
  enable_registry: true,
  log_level: :debug

# Configure the development environment
config :packetflow,
  validate_capabilities: true,
  enable_registry: true,
  log_level: :info

# Configure the production environment
config :packetflow,
  validate_capabilities: true,
  enable_registry: true,
  log_level: :warn
