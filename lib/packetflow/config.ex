defmodule PacketFlow.Config do
  @moduledoc """
  Dynamic configuration management for PacketFlow components

  This module provides centralized configuration management with support for:
  - Environment-based configuration
  - Runtime configuration updates
  - Component-specific configuration
  - Configuration validation
  - Default value management
  """

  use GenServer

  @type config_key :: atom()
  @type config_value :: any()
  @type config_map :: %{config_key() => config_value()}

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_opts) do
    # Load initial configuration from application config
    initial_config = load_application_config()
    {:ok, %{config: initial_config, watchers: %{}}}
  end

  @doc """
  Get a configuration value with optional default
  """
  @spec get(config_key(), config_value()) :: config_value()
  def get(key, default \\ nil) do
    GenServer.call(__MODULE__, {:get, key, default})
  end

  @doc """
  Get a configuration value for a specific component
  """
  @spec get_component(atom(), config_key(), config_value()) :: config_value()
  def get_component(component, key, default \\ nil) do
    GenServer.call(__MODULE__, {:get_component, component, key, default})
  end

  @doc """
  Set a configuration value
  """
  @spec set(config_key(), config_value()) :: :ok
  def set(key, value) do
    GenServer.call(__MODULE__, {:set, key, value})
  end

  @doc """
  Set a configuration value for a specific component
  """
  @spec set_component(atom(), config_key(), config_value()) :: :ok
  def set_component(component, key, value) do
    GenServer.call(__MODULE__, {:set_component, component, key, value})
  end

  @doc """
  Update configuration with a map of values
  """
  @spec update(config_map()) :: :ok
  def update(config_map) do
    GenServer.call(__MODULE__, {:update, config_map})
  end

  @doc """
  Get all configuration
  """
  @spec get_all() :: config_map()
  def get_all do
    GenServer.call(__MODULE__, :get_all)
  end

  @doc """
  Validate configuration against schema
  """
  @spec validate(config_map()) :: {:ok, config_map()} | {:error, String.t()}
  def validate(config) do
    case validate_config_schema(config) do
      :ok -> {:ok, config}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Watch for configuration changes
  """
  @spec watch(config_key(), pid()) :: :ok
  def watch(key, pid) do
    GenServer.call(__MODULE__, {:watch, key, pid})
  end

  @doc """
  Unwatch configuration changes
  """
  @spec unwatch(config_key(), pid()) :: :ok
  def unwatch(key, pid) do
    GenServer.call(__MODULE__, {:unwatch, key, pid})
  end

  # GenServer callbacks

  def handle_call({:get, key, default}, _from, state) do
    value = Map.get(state.config, key, default)
    {:reply, value, state}
  end

  def handle_call({:get_component, component, key, default}, _from, state) do
    component_config = Map.get(state.config, component, %{})
    value = Map.get(component_config, key, default)
    {:reply, value, state}
  end

  def handle_call({:set, key, value}, _from, state) do
    new_config = Map.put(state.config, key, value)
    new_state = %{state | config: new_config}
    notify_watchers(key, value, state.watchers)
    {:reply, :ok, new_state}
  end

  def handle_call({:set_component, component, key, value}, _from, state) do
    component_config = Map.get(state.config, component, %{})
    updated_component_config = Map.put(component_config, key, value)
    new_config = Map.put(state.config, component, updated_component_config)
    new_state = %{state | config: new_config}
    notify_watchers({component, key}, value, state.watchers)
    {:reply, :ok, new_state}
  end

  def handle_call({:update, config_map}, _from, state) do
    new_config = Map.merge(state.config, config_map)
    new_state = %{state | config: new_config}
    notify_watchers_for_map(config_map, state.watchers)
    {:reply, :ok, new_state}
  end

  def handle_call(:get_all, _from, state) do
    {:reply, state.config, state}
  end

  def handle_call({:watch, key, pid}, _from, state) do
    watchers = Map.update(state.watchers, key, [pid], &[pid | &1])
    new_state = %{state | watchers: watchers}
    {:reply, :ok, new_state}
  end

  def handle_call({:unwatch, key, pid}, _from, state) do
    watchers = Map.update(state.watchers, key, [], &List.delete(&1, pid))
    new_state = %{state | watchers: watchers}
    {:reply, :ok, new_state}
  end

  # Private functions

  defp load_application_config do
    # Load configuration from application config
    base_config = Application.get_env(:packetflow, []) || []

    # Add default component configurations
    default_config = %{
      # Stream component defaults
      stream: %{
        backpressure_strategy: :drop_oldest,
        window_size: 1000,
        processing_timeout: 5000,
        buffer_size: 10000,
        batch_size: 100
      },

      # Temporal component defaults
      temporal: %{
        business_hours_start: {9, 0},
        business_hours_end: {17, 0},
        timezone: "UTC",
        scheduling_enabled: true,
        validation_enabled: true
      },

      # Actor component defaults
      actor: %{
        routing_strategy: :round_robin,
        supervision_strategy: :one_for_one,
        max_restarts: 3,
        restart_interval: 5000
      },

      # Capability component defaults
      capability: %{
        validation_enabled: true,
        delegation_enabled: true,
        composition_enabled: true,
        inheritance_enabled: true
      },

      # Intent component defaults
      intent: %{
        routing_enabled: true,
        transformation_enabled: true,
        validation_enabled: true,
        composition_enabled: true
      },

      # Context component defaults
      context: %{
        propagation_enabled: true,
        composition_enabled: true,
        validation_enabled: true,
        caching_enabled: true
      },

      # Reactor component defaults
      reactor: %{
        processing_enabled: true,
        composition_enabled: true,
        validation_enabled: true,
        monitoring_enabled: true
      }
    }

    Map.merge(default_config, Map.new(base_config || []))
  end

  defp validate_config_schema(config) do
    # Basic validation - can be extended with more sophisticated schema validation
    case validate_config_types(config) do
      :ok -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp validate_config_types(config) when is_map(config) do
    # Validate that all values are of expected types
    Enum.reduce_while(config, :ok, fn {key, value}, _acc ->
      case validate_value_type(key, value) do
        :ok -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, "Invalid type for #{key}: #{reason}"}}
      end
    end)
  end

  defp validate_config_types(_), do: {:error, "Configuration must be a map"}

  defp validate_value_type(_key, value) when is_map(value) do
    # Recursively validate nested maps
    validate_config_types(value)
  end

  defp validate_value_type(_key, value) when is_atom(value) or is_integer(value) or is_float(value) or is_binary(value) or is_boolean(value) or is_tuple(value) do
    :ok
  end

  defp validate_value_type(key, value) do
    {:error, "Unsupported type for #{key}: #{inspect(value)}"}
  end

  defp notify_watchers(key, value, watchers) do
    case Map.get(watchers, key) do
      nil -> :ok
      pids -> Enum.each(pids, &send(&1, {:config_changed, key, value}))
    end
  end

  defp notify_watchers_for_map(config_map, watchers) do
    Enum.each(config_map, fn {key, value} ->
      notify_watchers(key, value, watchers)
    end)
  end
end
