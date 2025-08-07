import Config

# Import plugin configuration
import_config "plugins.exs"

# Configure the application
config :packetflow,
  validate_capabilities: true,
  enable_registry: true,
  log_level: :info

# Component-specific configurations
config :packetflow, :components, [
  capability: [
    validation_enabled: true,
    delegation_enabled: true,
    composition_enabled: true
  ],
  intent: [
    routing_enabled: true,
    transformation_enabled: true,
    validation_enabled: true
  ],
  context: [
    propagation_enabled: true,
    composition_enabled: true,
    validation_enabled: true
  ],
  reactor: [
    processing_enabled: true,
    composition_enabled: true,
    validation_enabled: true
  ],
  stream: [
    processing_enabled: true,
    backpressure_enabled: true,
    windowing_enabled: true
  ],
  temporal: [
    processing_enabled: true,
    scheduling_enabled: true,
    validation_enabled: true
  ]
]

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
