# Plugin configuration for PacketFlow
# This file defines which plugins are loaded and their configurations

import Config

# Plugin configuration
config :packetflow, :plugins, [
  capability_plugins: [
    "PacketFlow.Plugin.Capability.Custom",
    "PacketFlow.Plugin.Capability.Advanced"
  ],
  intent_plugins: [
    "PacketFlow.Plugin.Intent.Custom",
    "PacketFlow.Plugin.Intent.Advanced"
  ],
  context_plugins: [
    "PacketFlow.Plugin.Context.Custom",
    "PacketFlow.Plugin.Context.Advanced"
  ],
  reactor_plugins: [
    "PacketFlow.Plugin.Reactor.Custom",
    "PacketFlow.Plugin.Reactor.Advanced"
  ],
  stream_plugins: [
    "PacketFlow.Plugin.Stream.Custom",
    "PacketFlow.Plugin.Stream.Advanced"
  ],
  temporal_plugins: [
    "PacketFlow.Plugin.Temporal.Custom",
    "PacketFlow.Plugin.Temporal.Advanced"
  ],
  web_plugins: [
    "PacketFlow.Plugin.Web.Custom",
    "PacketFlow.Plugin.Web.Advanced"
  ],
  test_plugins: [
    "PacketFlow.Plugin.Test.Custom",
    "PacketFlow.Plugin.Test.Advanced"
  ],
  docs_plugins: [
    "PacketFlow.Plugin.Docs.Custom",
    "PacketFlow.Plugin.Docs.Advanced"
  ]
]

# Plugin discovery configuration
config :packetflow, :plugin_discovery, [
  enabled: true,
  auto_load: true,
  scan_paths: [
    "lib/packetflow/plugins",
    "priv/plugins"
  ],
  scan_pattern: "**/*.ex"
]

# Plugin validation configuration
config :packetflow, :plugin_validation, [
  enabled: true,
  strict_mode: false,
  validate_dependencies: true,
  validate_interfaces: true
]

# Plugin hot-swapping configuration
config :packetflow, :plugin_hotswap, [
  enabled: true,
  auto_reload: false,
  reload_interval: 5000,
  max_reload_attempts: 3
]
