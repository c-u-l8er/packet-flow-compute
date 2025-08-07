defmodule PacketFlow.Component do
  @moduledoc """
  Component lifecycle management for PacketFlow

  This module provides:
  - Component initialization
  - Component state management
  - Component dependency injection
  - Component cleanup
  - Component health monitoring
  """

  use GenServer

  @type component_id :: atom()
  @type component_state :: map()
  @type component_config :: map()
  @type component_info :: %{
    id: component_id(),
    module: module(),
    state: component_state(),
    config: component_config(),
    dependencies: [component_id()],
    health: :healthy | :unhealthy | :degraded,
    last_heartbeat: integer()
  }

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_opts) do
    {:ok, %{components: %{}, watchers: %{}, health_check_interval: 30000}}
  end

  @doc """
  Register a component
  """
  @spec register_component(component_id(), module(), component_config()) :: {:ok, component_info()} | {:error, String.t()}
  def register_component(id, module, config \\ %{}) do
    GenServer.call(__MODULE__, {:register_component, id, module, config})
  end

  @doc """
  Unregister a component
  """
  @spec unregister_component(component_id()) :: :ok | {:error, String.t()}
  def unregister_component(id) do
    GenServer.call(__MODULE__, {:unregister_component, id})
  end

  @doc """
  Get component information
  """
  @spec get_component_info(component_id()) :: component_info() | nil
  def get_component_info(id) do
    GenServer.call(__MODULE__, {:get_component_info, id})
  end

  @doc """
  List all components
  """
  @spec list_components() :: [component_id()]
  def list_components do
    GenServer.call(__MODULE__, :list_components)
  end

  @doc """
  Update component state
  """
  @spec update_component_state(component_id(), component_state()) :: :ok | {:error, String.t()}
  def update_component_state(id, state) do
    GenServer.call(__MODULE__, {:update_component_state, id, state})
  end

  @doc """
  Update component configuration
  """
  @spec update_component_config(component_id(), component_config()) :: :ok | {:error, String.t()}
  def update_component_config(id, config) do
    GenServer.call(__MODULE__, {:update_component_config, id, config})
  end

  @doc """
  Add component dependency
  """
  @spec add_component_dependency(component_id(), component_id()) :: :ok | {:error, String.t()}
  def add_component_dependency(id, dependency_id) do
    GenServer.call(__MODULE__, {:add_component_dependency, id, dependency_id})
  end

  @doc """
  Remove component dependency
  """
  @spec remove_component_dependency(component_id(), component_id()) :: :ok | {:error, String.t()}
  def remove_component_dependency(id, dependency_id) do
    GenServer.call(__MODULE__, {:remove_component_dependency, id, dependency_id})
  end

  @doc """
  Get component health
  """
  @spec get_component_health(component_id()) :: :healthy | :unhealthy | :degraded | nil
  def get_component_health(id) do
    GenServer.call(__MODULE__, {:get_component_health, id})
  end

  @doc """
  Check component health
  """
  @spec check_component_health(component_id()) :: :ok | {:error, String.t()}
  def check_component_health(id) do
    GenServer.call(__MODULE__, {:check_component_health, id})
  end

  @doc """
  Watch component lifecycle events
  """
  @spec watch_component(component_id(), pid()) :: :ok
  def watch_component(id, pid) do
    GenServer.call(__MODULE__, {:watch_component, id, pid})
  end

  @doc """
  Unwatch component lifecycle events
  """
  @spec unwatch_component(component_id(), pid()) :: :ok
  def unwatch_component(id, pid) do
    GenServer.call(__MODULE__, {:unwatch_component, id, pid})
  end

  # GenServer callbacks

  def handle_call({:register_component, id, module, config}, _from, state) do
    case Map.get(state.components, id) do
      nil ->
        component_info = %{
          id: id,
          module: module,
          state: %{},
          config: config,
          dependencies: [],
          health: :healthy,
          last_heartbeat: System.system_time(:millisecond)
        }

        new_state = %{state | components: Map.put(state.components, id, component_info)}
        notify_watchers({:component_registered, id}, component_info, state.watchers)
        {:reply, {:ok, component_info}, new_state}

      _existing ->
        {:reply, {:error, "Component already registered: #{id}"}, state}
    end
  end

  def handle_call({:unregister_component, id}, _from, state) do
    case Map.get(state.components, id) do
      nil ->
        {:reply, {:error, "Component not found: #{id}"}, state}

      component_info ->
        # Check for dependent components
        dependents = find_dependent_components(id, state.components)

        case dependents do
          [] ->
            new_state = %{state | components: Map.delete(state.components, id)}
            notify_watchers({:component_unregistered, id}, id, state.watchers)
            {:reply, :ok, new_state}

          deps ->
            {:reply, {:error, "Cannot unregister component with dependents: #{Enum.join(deps, ", ")}"}, state}
        end
    end
  end

  def handle_call({:get_component_info, id}, _from, state) do
    component_info = Map.get(state.components, id)
    {:reply, component_info, state}
  end

  def handle_call(:list_components, _from, state) do
    component_ids = Map.keys(state.components)
    {:reply, component_ids, state}
  end

  def handle_call({:update_component_state, id, new_state}, _from, state) do
    case Map.get(state.components, id) do
      nil ->
        {:reply, {:error, "Component not found: #{id}"}, state}

      component_info ->
        updated_component = %{component_info | state: new_state}
        new_components = Map.put(state.components, id, updated_component)
        new_state = %{state | components: new_components}
        notify_watchers({:component_state_updated, id}, new_state, state.watchers)
        {:reply, :ok, new_state}
    end
  end

  def handle_call({:update_component_config, id, new_config}, _from, state) do
    case Map.get(state.components, id) do
      nil ->
        {:reply, {:error, "Component not found: #{id}"}, state}

      component_info ->
        updated_component = %{component_info | config: new_config}
        new_components = Map.put(state.components, id, updated_component)
        new_state = %{state | components: new_components}
        notify_watchers({:component_config_updated, id}, new_config, state.watchers)
        {:reply, :ok, new_state}
    end
  end

  def handle_call({:add_component_dependency, id, dependency_id}, _from, state) do
    case {Map.get(state.components, id), Map.get(state.components, dependency_id)} do
      {nil, _} ->
        {:reply, {:error, "Component not found: #{id}"}, state}

      {_, nil} ->
        {:reply, {:error, "Dependency not found: #{dependency_id}"}, state}

      {component_info, _dependency_info} ->
        # Check for circular dependencies
        case check_circular_dependency(id, dependency_id, state.components) do
          :ok ->
            updated_dependencies = [dependency_id | component_info.dependencies]
            updated_component = %{component_info | dependencies: updated_dependencies}
            new_components = Map.put(state.components, id, updated_component)
            new_state = %{state | components: new_components}
            notify_watchers({:component_dependency_added, id, dependency_id}, dependency_id, state.watchers)
            {:reply, :ok, new_state}

          {:error, reason} ->
            {:reply, {:error, reason}, state}
        end
    end
  end

  def handle_call({:remove_component_dependency, id, dependency_id}, _from, state) do
    case Map.get(state.components, id) do
      nil ->
        {:reply, {:error, "Component not found: #{id}"}, state}

      component_info ->
        updated_dependencies = List.delete(component_info.dependencies, dependency_id)
        updated_component = %{component_info | dependencies: updated_dependencies}
        new_components = Map.put(state.components, id, updated_component)
        new_state = %{state | components: new_components}
        notify_watchers({:component_dependency_removed, id, dependency_id}, dependency_id, state.watchers)
        {:reply, :ok, new_state}
    end
  end

  def handle_call({:get_component_health, id}, _from, state) do
    case Map.get(state.components, id) do
      nil -> {:reply, nil, state}
      component_info -> {:reply, component_info.health, state}
    end
  end

  def handle_call({:check_component_health, id}, _from, state) do
    case Map.get(state.components, id) do
      nil ->
        {:reply, {:error, "Component not found: #{id}"}, state}

      component_info ->
        case perform_health_check(component_info) do
          {:ok, health} ->
            updated_component = %{component_info | health: health, last_heartbeat: System.system_time(:millisecond)}
            new_components = Map.put(state.components, id, updated_component)
            new_state = %{state | components: new_components}
            notify_watchers({:component_health_updated, id}, health, state.watchers)
            {:reply, :ok, new_state}

          {:error, reason} ->
            {:reply, {:error, reason}, state}
        end
    end
  end

  def handle_call({:watch_component, id, pid}, _from, state) do
    watchers = Map.update(state.watchers, id, [pid], &[pid | &1])
    new_state = %{state | watchers: watchers}
    {:reply, :ok, new_state}
  end

  def handle_call({:unwatch_component, id, pid}, _from, state) do
    watchers = Map.update(state.watchers, id, [], &List.delete(&1, pid))
    new_state = %{state | watchers: watchers}
    {:reply, :ok, new_state}
  end

  # Private functions

  defp find_dependent_components(id, components) do
    Enum.filter(components, fn {_comp_id, component_info} ->
      id in component_info.dependencies
    end)
    |> Enum.map(fn {comp_id, _} -> comp_id end)
  end

  defp check_circular_dependency(id, dependency_id, components) do
    # Simple circular dependency check
    if id == dependency_id do
      {:error, "Self-dependency not allowed"}
    else
      :ok
    end
  end

  defp perform_health_check(component_info) do
    # Basic health check - can be extended with more sophisticated checks
    current_time = System.system_time(:millisecond)
    time_since_heartbeat = current_time - component_info.last_heartbeat

    cond do
      time_since_heartbeat > 60000 -> {:ok, :unhealthy}
      time_since_heartbeat > 30000 -> {:ok, :degraded}
      true -> {:ok, :healthy}
    end
  end

  defp notify_watchers(event, data, watchers) do
    # Notify all watchers of component events
    Enum.each(watchers, fn {component_id, pids} ->
      Enum.each(pids, fn pid ->
        send(pid, {:component_event, event, data})
      end)
    end)
  end
end
