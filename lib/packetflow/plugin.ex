defmodule PacketFlow.Plugin do
  @moduledoc """
  Plugin system for extending PacketFlow functionality

  This module provides:
  - Plugin discovery and loading
  - Plugin lifecycle management
  - Plugin dependency resolution
  - Plugin configuration
  - Plugin hot-swapping
  """

  use GenServer

  @type plugin_id :: atom()
  @type plugin_info :: %{
    id: plugin_id(),
    module: module(),
    version: String.t(),
    dependencies: [plugin_id()],
    config: map()
  }

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_opts) do
    # Load plugins from configuration
    plugins = load_plugins_from_config()
    {:ok, %{plugins: plugins, loaded_plugins: %{}, watchers: %{}}}
  end

  @doc """
  Load a plugin by module name
  """
  @spec load_plugin(module()) :: {:ok, plugin_info()} | {:error, String.t()}
  def load_plugin(module) when is_atom(module) do
    GenServer.call(__MODULE__, {:load_plugin, module})
  end

  @doc """
  Unload a plugin by ID
  """
  @spec unload_plugin(plugin_id()) :: :ok | {:error, String.t()}
  def unload_plugin(plugin_id) do
    GenServer.call(__MODULE__, {:unload_plugin, plugin_id})
  end

  @doc """
  Get information about a loaded plugin
  """
  @spec get_plugin_info(plugin_id()) :: plugin_info() | nil
  def get_plugin_info(plugin_id) do
    GenServer.call(__MODULE__, {:get_plugin_info, plugin_id})
  end

  @doc """
  List all loaded plugins
  """
  @spec list_plugins() :: [plugin_id()]
  def list_plugins do
    GenServer.call(__MODULE__, :list_plugins)
  end

  @doc """
  Check if a plugin is loaded
  """
  @spec plugin_loaded?(plugin_id()) :: boolean()
  def plugin_loaded?(plugin_id) do
    GenServer.call(__MODULE__, {:plugin_loaded?, plugin_id})
  end

  @doc """
  Get plugin configuration
  """
  @spec get_plugin_config(plugin_id()) :: map()
  def get_plugin_config(plugin_id) do
    GenServer.call(__MODULE__, {:get_plugin_config, plugin_id})
  end

  @doc """
  Set plugin configuration
  """
  @spec set_plugin_config(plugin_id(), map()) :: :ok
  def set_plugin_config(plugin_id, config) do
    GenServer.call(__MODULE__, {:set_plugin_config, plugin_id, config})
  end

  @doc """
  Watch for plugin lifecycle events
  """
  @spec watch_plugin(plugin_id(), pid()) :: :ok
  def watch_plugin(plugin_id, pid) do
    GenServer.call(__MODULE__, {:watch_plugin, plugin_id, pid})
  end

  @doc """
  Unwatch plugin lifecycle events
  """
  @spec unwatch_plugin(plugin_id(), pid()) :: :ok
  def unwatch_plugin(plugin_id, pid) do
    GenServer.call(__MODULE__, {:unwatch_plugin, plugin_id, pid})
  end

  # GenServer callbacks

  def handle_call({:load_plugin, module}, _from, state) do
    case load_plugin_module(module, state) do
      {:ok, plugin_info} ->
        new_state = %{state | loaded_plugins: Map.put(state.loaded_plugins, plugin_info.id, plugin_info)}
        notify_watchers({:plugin_loaded, plugin_info.id}, plugin_info, state.watchers)
        {:reply, {:ok, plugin_info}, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:unload_plugin, plugin_id}, _from, state) do
    case Map.get(state.loaded_plugins, plugin_id) do
      nil ->
        {:reply, {:error, "Plugin not found: #{plugin_id}"}, state}

      plugin_info ->
        case unload_plugin_module(plugin_info) do
          :ok ->
            new_state = %{state | loaded_plugins: Map.delete(state.loaded_plugins, plugin_id)}
            notify_watchers({:plugin_unloaded, plugin_id}, plugin_id, state.watchers)
            {:reply, :ok, new_state}

          {:error, reason} ->
            {:reply, {:error, reason}, state}
        end
    end
  end

  def handle_call({:get_plugin_info, plugin_id}, _from, state) do
    plugin_info = Map.get(state.loaded_plugins, plugin_id)
    {:reply, plugin_info, state}
  end

  def handle_call(:list_plugins, _from, state) do
    plugin_ids = Map.keys(state.loaded_plugins)
    {:reply, plugin_ids, state}
  end

  def handle_call({:plugin_loaded?, plugin_id}, _from, state) do
    loaded = Map.has_key?(state.loaded_plugins, plugin_id)
    {:reply, loaded, state}
  end

  def handle_call({:get_plugin_config, plugin_id}, _from, state) do
    case Map.get(state.loaded_plugins, plugin_id) do
      nil -> {:reply, %{}, state}
      plugin_info -> {:reply, plugin_info.config, state}
    end
  end

  def handle_call({:set_plugin_config, plugin_id, config}, _from, state) do
    case Map.get(state.loaded_plugins, plugin_id) do
      nil ->
        {:reply, {:error, "Plugin not found: #{plugin_id}"}, state}

      plugin_info ->
        updated_plugin_info = %{plugin_info | config: config}
        new_state = %{state | loaded_plugins: Map.put(state.loaded_plugins, plugin_id, updated_plugin_info)}
        notify_watchers({:plugin_config_changed, plugin_id}, config, state.watchers)
        {:reply, :ok, new_state}
    end
  end

  def handle_call({:watch_plugin, plugin_id, pid}, _from, state) do
    watchers = Map.update(state.watchers, plugin_id, [pid], &[pid | &1])
    new_state = %{state | watchers: watchers}
    {:reply, :ok, new_state}
  end

  def handle_call({:unwatch_plugin, plugin_id, pid}, _from, state) do
    watchers = Map.update(state.watchers, plugin_id, [], &List.delete(&1, pid))
    new_state = %{state | watchers: watchers}
    {:reply, :ok, new_state}
  end

  # Private functions

  defp load_plugins_from_config do
    # Load plugin configuration from application config
    plugins_config = Application.get_env(:packetflow, :plugins, [])

    # Convert to plugin info map
    Enum.reduce(plugins_config, %{}, fn {plugin_type, modules}, acc ->
      plugin_infos = Enum.map(modules, fn module ->
        %{
          id: String.to_atom("#{plugin_type}_#{module}"),
          module: module,
          version: "1.0.0",
          dependencies: [],
          config: %{}
        }
      end)

      Map.merge(acc, Map.new(plugin_infos, fn info -> {info.id, info} end))
    end)
  end

  defp load_plugin_module(module, state) do
    # Check if module exists
    case Code.ensure_loaded(module) do
      {:module, _} ->
        # Validate plugin interface
        case validate_plugin_interface(module) do
          :ok ->
                         plugin_info = %{
               id: module_to_plugin_id(module),
               module: module,
               version: get_plugin_version(module),
               dependencies: get_plugin_dependencies(module),
               config: get_plugin_default_config(module)
             }

            # Check dependencies
            case check_plugin_dependencies(plugin_info, state.loaded_plugins) do
              :ok ->
                # Initialize plugin
                case initialize_plugin(module, plugin_info) do
                  :ok -> {:ok, plugin_info}
                  {:error, reason} -> {:error, "Failed to initialize plugin: #{reason}"}
                end

              {:error, reason} ->
                {:error, "Plugin dependency error: #{reason}"}
            end

          {:error, reason} ->
            {:error, "Invalid plugin interface: #{reason}"}
        end

      {:error, reason} ->
        {:error, "Failed to load module: #{reason}"}
    end
  end

  defp unload_plugin_module(plugin_info) do
    # Call plugin cleanup if available
    case function_exported?(plugin_info.module, :cleanup, 0) do
      true -> plugin_info.module.cleanup()
      false -> :ok
    end
  end

  defp validate_plugin_interface(module) do
    # Check for required plugin interface functions
    required_functions = [:init, :process]
    missing_functions = Enum.filter(required_functions, fn func ->
      not function_exported?(module, func, 1)
    end)

    case missing_functions do
      [] -> :ok
      missing -> {:error, "Missing required functions: #{Enum.join(missing, ", ")}"}
    end
  end

  defp module_to_plugin_id(module) do
    module
    |> Atom.to_string()
    |> String.split(".")
    |> List.last()
    |> String.downcase()
    |> String.to_atom()
  end

  defp get_plugin_version(module) do
    case function_exported?(module, :version, 0) do
      true -> module.version()
      false -> "1.0.0"
    end
  end

  defp get_plugin_dependencies(module) do
    case function_exported?(module, :dependencies, 0) do
      true -> module.dependencies()
      false -> []
    end
  end

  defp get_plugin_default_config(module) do
    case function_exported?(module, :default_config, 0) do
      true -> module.default_config()
      false -> %{}
    end
  end

  defp check_plugin_dependencies(plugin_info, loaded_plugins) do
    # Check if all dependencies are loaded
    missing_deps = Enum.filter(plugin_info.dependencies, fn dep ->
      not Map.has_key?(loaded_plugins, dep)
    end)

    case missing_deps do
      [] -> :ok
      missing -> {:error, "Missing dependencies: #{Enum.join(missing, ", ")}"}
    end
  end

  defp initialize_plugin(module, plugin_info) do
    # Call plugin init function
    case function_exported?(module, :init, 1) do
      true -> module.init(plugin_info.config)
      false -> :ok
    end
  end

  defp notify_watchers(event, data, watchers) do
    # Notify all watchers of plugin events
    Enum.each(watchers, fn {plugin_id, pids} ->
      Enum.each(pids, fn pid ->
        send(pid, {:plugin_event, event, data})
      end)
    end)
  end
end
