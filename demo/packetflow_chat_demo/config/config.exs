# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
import Config

# Configure the main view controller for the Phoenix application
config :packetflow_chat_demo, :web_port, 4000

# Configure logging
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Configure PacketFlow logging
config :logger, :packetflow,
  level: :info,
  format: "$time [$level] $message\n"

# Development configuration
if config_env() == :dev do
  config :logger, level: :debug

  # Enable more verbose PacketFlow logging in development
  config :logger, :packetflow, level: :debug
end

# Test configuration
if config_env() == :test do
  config :logger, level: :warn

  # Disable PacketFlow logging in tests
  config :logger, :packetflow, level: :warn
end

# Production configuration
if config_env() == :prod do
  config :logger, level: :info

  # Production PacketFlow logging
  config :logger, :packetflow, level: :info
end
