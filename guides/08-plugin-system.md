# Plugin System Guide

## What is the Plugin System?

The **Plugin System** is PacketFlow's extensibility layer. It provides hot-swappable extensions with dynamic loading, plugin lifecycle management, dependency resolution, and configuration management.

Think of it as the "extensibility layer" that allows you to add new functionality to your system without restarting or modifying the core code.

## Core Concepts

### Plugin Architecture

The Plugin System provides:
- **Hot-swappable extensions** that can be loaded/unloaded at runtime
- **Plugin lifecycle management** (load, unload, reload)
- **Dependency resolution** between plugins
- **Configuration management** for plugins
- **Plugin discovery** and automatic loading

In PacketFlow, plugins are enhanced with:
- **Capability-aware extensions**
- **Context propagation** to plugins
- **Interface compliance** checking
- **Automatic dependency resolution**

## Key Components

### 1. **Plugin Interface** (Standardized Extensions)
Plugins implement a standard interface for integration.

```elixir
defmodule FileSystem.Plugins.EncryptionPlugin do
  use PacketFlow.Plugin

  # Implement the standard plugin interface
  @behaviour PacketFlow.Plugin.Interface

  def plugin_info do
    %{
      name: "encryption_plugin",
      version: "1.0.0",
      description: "File encryption and decryption",
      capabilities: [FileCap.encrypt("/"), FileCap.decrypt("/")],
      dependencies: []
    }
  end

  def init(config) do
    # Initialize plugin
    {:ok, %{config: config, encryption_key: config[:encryption_key]}}
  end

  def handle_intent(intent, context, state) do
    case intent do
      %FileSystem.Intents.EncryptFile{path: path, user_id: user_id} ->
        encrypt_file(path, user_id, context, state)
      
      %FileSystem.Intents.DecryptFile{path: path, user_id: user_id} ->
        decrypt_file(path, user_id, context, state)
    end
  end

  def cleanup do
    # Cleanup plugin resources
    :ok
  end

  # Private helper functions
  defp encrypt_file(path, user_id, context, state) do
    # Check capabilities
    if has_capability?(context, FileCap.encrypt(path)) do
      # Encrypt file
      case File.read(path) do
        {:ok, content} ->
          encrypted_content = encrypt_content(content, state.encryption_key)
          File.write(path, encrypted_content)
          {:ok, %{encrypted: true, path: path}}
        
        {:error, reason} ->
          {:error, reason}
      end
    else
      {:error, :insufficient_capabilities}
    end
  end

  defp decrypt_file(path, user_id, context, state) do
    # Check capabilities
    if has_capability?(context, FileCap.decrypt(path)) do
      # Decrypt file
      case File.read(path) do
        {:ok, encrypted_content} ->
          decrypted_content = decrypt_content(encrypted_content, state.encryption_key)
          File.write(path, decrypted_content)
          {:ok, %{decrypted: true, path: path}}
        
        {:error, reason} ->
          {:error, reason}
      end
    else
      {:error, :insufficient_capabilities}
    end
  end

  defp encrypt_content(content, key) do
    # Simple encryption (use proper encryption in production)
    Base.encode64(content)
  end

  defp decrypt_content(encrypted_content, key) do
    # Simple decryption (use proper decryption in production)
    Base.decode64!(encrypted_content)
  end
end
```

### 2. **Plugin Manager** (Lifecycle Management)
The plugin manager handles plugin loading, unloading, and lifecycle.

```elixir
defmodule FileSystem.Plugins.PluginManager do
  use PacketFlow.Plugin

  def init(_args) do
    {:ok, %{
      loaded_plugins: %{},
      plugin_configs: %{},
      dependency_graph: %{}
    }}
  end

  # Load a plugin
  def load_plugin(plugin_module, config \\ %{}) do
    # Get plugin info
    plugin_info = plugin_module.plugin_info()
    
    # Check dependencies
    case check_plugin_dependencies(plugin_info.dependencies) do
      :ok ->
        # Initialize plugin
        case plugin_module.init(config) do
          {:ok, state} ->
            # Register plugin
            new_plugins = Map.put(state.loaded_plugins, plugin_info.name, %{
              module: plugin_module,
              info: plugin_info,
              state: state,
              config: config
            })
            
            # Update dependency graph
            new_graph = update_dependency_graph(state.dependency_graph, plugin_info)
            
            {:ok, %{state | 
              loaded_plugins: new_plugins,
              dependency_graph: new_graph
            }}
          
          {:error, reason} ->
            {:error, reason}
        end
      
      {:error, reason} ->
        {:error, reason}
    end
  end

  # Unload a plugin
  def unload_plugin(plugin_name) do
    case Map.get(state.loaded_plugins, plugin_name) do
      nil ->
        {:error, :plugin_not_found}
      
      plugin ->
        # Check if other plugins depend on this one
        case check_plugin_dependents(plugin_name) do
          [] ->
            # No dependents, safe to unload
            plugin.module.cleanup()
            
            new_plugins = Map.delete(state.loaded_plugins, plugin_name)
            new_graph = remove_from_dependency_graph(state.dependency_graph, plugin_name)
            
            {:ok, %{state | 
              loaded_plugins: new_plugins,
              dependency_graph: new_graph
            }}
          
          dependents ->
            {:error, {:has_dependents, dependents}}
        end
    end
  end

  # Route intent to appropriate plugin
  def route_intent_to_plugin(intent, context) do
    # Find plugin that can handle this intent
    case find_plugin_for_intent(intent) do
      nil ->
        {:error, :no_plugin_found}
      
      plugin_name ->
        plugin = Map.get(state.loaded_plugins, plugin_name)
        plugin.module.handle_intent(intent, context, plugin.state)
    end
  end

  # Private helper functions
  defp check_plugin_dependencies(dependencies) do
    Enum.all?(dependencies, fn dep ->
      Map.has_key?(state.loaded_plugins, dep)
    end)
    |> case do
      true -> :ok
      false -> {:error, :missing_dependencies}
    end
  end

  defp find_plugin_for_intent(intent) do
    # Find plugin that can handle this intent type
    Enum.find(Map.keys(state.loaded_plugins), fn plugin_name ->
      plugin = Map.get(state.loaded_plugins, plugin_name)
      can_handle_intent?(plugin, intent)
    end)
  end

  defp can_handle_intent?(plugin, intent) do
    # Check if plugin can handle this intent
    # This is a simplified check
    intent_type = get_intent_type(intent)
    Enum.member?(plugin.info.capabilities, intent_type)
  end

  defp get_intent_type(intent) do
    # Extract intent type
    case intent do
      %FileSystem.Intents.EncryptFile{} -> FileCap.encrypt("/")
      %FileSystem.Intents.DecryptFile{} -> FileCap.decrypt("/")
      _ -> :unknown
    end
  end
end
```

## How It Works

### 1. **Plugin Loading and Registration**
Plugins are loaded dynamically and registered with the system:

```elixir
# Load a plugin
{:ok, _} = PacketFlow.Plugin.load_plugin(FileSystem.Plugins.EncryptionPlugin, %{
  encryption_key: "secret_key_123"
})

# Plugin is now available for use
# System can route encryption intents to it
```

### 2. **Intent Routing to Plugins**
Intents are automatically routed to appropriate plugins:

```elixir
# Create encryption intent
intent = FileSystem.Intents.EncryptFile.new("/secret.txt", "user123")
context = FileSystem.Contexts.FileContext.new("user123", "session456", [FileCap.encrypt("/")])

# Intent is automatically routed to encryption plugin
{:ok, result} = PacketFlow.Plugin.route_intent_to_plugin(intent, context)
# => {:ok, %{encrypted: true, path: "/secret.txt"}}
```

### 3. **Plugin Lifecycle Management**
Plugins can be loaded, unloaded, and reloaded at runtime:

```elixir
# Unload plugin
{:ok, _} = PacketFlow.Plugin.unload_plugin(:encryption_plugin)

# Plugin is no longer available
{:error, :no_plugin_found} = PacketFlow.Plugin.route_intent_to_plugin(intent, context)

# Reload plugin with new configuration
{:ok, _} = PacketFlow.Plugin.load_plugin(FileSystem.Plugins.EncryptionPlugin, %{
  encryption_key: "new_secret_key"
})
```

## Advanced Features

### Plugin Dependency Resolution

```elixir
defmodule FileSystem.Plugins.DependencyResolver do
  def resolve_plugin_dependencies(plugin_info) do
    # Build dependency graph
    graph = build_dependency_graph(plugin_info)
    
    # Check for circular dependencies
    case detect_circular_dependencies(graph) do
      :ok ->
        # Sort plugins by dependency order
        sorted_plugins = topological_sort(graph)
        {:ok, sorted_plugins}
      
      {:error, cycle} ->
        {:error, {:circular_dependency, cycle}}
    end
  end

  defp build_dependency_graph(plugin_info) do
    # Build graph from plugin dependencies
    %{}
  end

  defp detect_circular_dependencies(graph) do
    # Detect circular dependencies
    :ok
  end

  defp topological_sort(graph) do
    # Sort plugins by dependency order
    []
  end
end
```

### Plugin Configuration Management

```elixir
defmodule FileSystem.Plugins.ConfigurationManager do
  def set_plugin_config(plugin_name, config) do
    # Validate configuration
    case validate_plugin_config(plugin_name, config) do
      :ok ->
        # Update plugin configuration
        PacketFlow.Plugin.update_config(plugin_name, config)
      
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp validate_plugin_config(plugin_name, config) do
    # Validate plugin-specific configuration
    :ok
  end
end
```

## Best Practices

### 1. **Design Plugin Interfaces Carefully**
Always implement the standard plugin interface:

```elixir
# Good: Implement all required interface functions
@behaviour PacketFlow.Plugin.Interface

def plugin_info do
  %{name: "my_plugin", version: "1.0.0", capabilities: [...]}
end

def init(config) do
  # Initialize plugin
end

def handle_intent(intent, context, state) do
  # Handle intent
end

def cleanup do
  # Cleanup resources
end
```

### 2. **Handle Plugin Failures Gracefully**
Always handle plugin failures:

```elixir
# Good: Handle plugin failures
def handle_plugin_failure(plugin_name, reason) do
  Logger.warning("Plugin #{plugin_name} failed: #{inspect(reason)}")
  
  # Try to reload plugin
  case reload_plugin(plugin_name) do
    {:ok, _} ->
      Logger.info("Plugin #{plugin_name} reloaded successfully")
    
    {:error, reload_reason} ->
      Logger.error("Failed to reload plugin #{plugin_name}: #{inspect(reload_reason)}")
  end
end
```

### 3. **Use Plugin Capabilities Appropriately**
Design plugins with clear capabilities:

```elixir
# Good: Clear capability definition
def plugin_info do
  %{
    name: "encryption_plugin",
    capabilities: [FileCap.encrypt("/"), FileCap.decrypt("/")],
    dependencies: []
  }
end

# Avoid: Vague or overly broad capabilities
def plugin_info do
  %{
    name: "do_everything_plugin",
    capabilities: [:everything],  # Too vague!
    dependencies: []
  }
end
```

## Common Patterns

### 1. **Capability Extension Plugin**
```elixir
defmodule FileSystem.Plugins.CapabilityExtension do
  use PacketFlow.Plugin

  def plugin_info do
    %{
      name: "capability_extension",
      version: "1.0.0",
      capabilities: [FileCap.admin("/admin/")],
      dependencies: []
    }
  end

  def handle_intent(intent, context, state) do
    # Extend system capabilities
    case intent do
      %FileSystem.Intents.AdminOperation{} ->
        handle_admin_operation(intent, context, state)
    end
  end
end
```

### 2. **Processing Pipeline Plugin**
```elixir
defmodule FileSystem.Plugins.ProcessingPipeline do
  use PacketFlow.Plugin

  def plugin_info do
    %{
      name: "processing_pipeline",
      version: "1.0.0",
      capabilities: [FileCap.process("/")],
      dependencies: []
    }
  end

  def handle_intent(intent, context, state) do
    # Process files through pipeline
    case intent do
      %FileSystem.Intents.ProcessFile{} ->
        process_file_pipeline(intent, context, state)
    end
  end
end
```

## Testing Your Plugin System

```elixir
defmodule FileSystem.Plugins.Test do
  use ExUnit.Case
  use PacketFlow.Testing

  test "plugin loads and handles intents correctly" do
    # Load test plugin
    {:ok, _} = PacketFlow.Plugin.load_plugin(FileSystem.Plugins.EncryptionPlugin)
    
    # Create test intent
    intent = FileSystem.Intents.EncryptFile.new("/test.txt", "user123")
    context = FileSystem.Contexts.FileContext.new("user123", "session456", [FileCap.encrypt("/")])
    
    # Route intent to plugin
    {:ok, result} = PacketFlow.Plugin.route_intent_to_plugin(intent, context)
    
    # Verify result
    assert result.encrypted == true
    assert result.path == "/test.txt"
  end

  test "plugin unloads correctly" do
    # Load plugin
    {:ok, _} = PacketFlow.Plugin.load_plugin(FileSystem.Plugins.EncryptionPlugin)
    
    # Unload plugin
    {:ok, _} = PacketFlow.Plugin.unload_plugin(:encryption_plugin)
    
    # Plugin should no longer be available
    intent = FileSystem.Intents.EncryptFile.new("/test.txt", "user123")
    context = FileSystem.Contexts.FileContext.new("user123", "session456", [FileCap.encrypt("/")])
    
    {:error, :no_plugin_found} = PacketFlow.Plugin.route_intent_to_plugin(intent, context)
  end
end
```

## Next Steps

Now that you understand the Plugin System, you can:

1. **Extend System Functionality**: Add new capabilities through plugins
2. **Build Plugin Ecosystems**: Create reusable plugin libraries
3. **Implement Hot-Swapping**: Update functionality without restarts
4. **Create Plugin Marketplaces**: Share plugins across systems

The Plugin System is your extensibility foundation - it makes your system flexible and adaptable!
