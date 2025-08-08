defmodule PacketFlow.Registry.Discovery do
  @moduledoc """
  Component discovery and lookup mechanisms

  This module provides sophisticated component discovery capabilities including:
  - Component pattern matching
  - Component capability matching
  - Component version matching
  - Component health filtering
  - Component load balancing
  """

  use GenServer

  @type discovery_pattern :: %{
    name: String.t() | :any,
    type: atom() | :any,
    capabilities: [term()] | :any,
    version: String.t() | :any,
    health: :healthy | :unhealthy | :degraded | :any,
    tags: [String.t()] | :any
  }

  @type component_match :: %{
    id: atom(),
    module: module(),
    metadata: map(),
    score: float()
  }

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_opts) do
    {:ok, %{
      components: %{},
      patterns: %{},
      load_balancer_state: %{},
      health_cache: %{},
      cache_ttl: 30_000 # 30 seconds
    }}
  end

  @doc """
  Register a component for discovery
  """
  @spec register_component(atom(), module(), map()) :: :ok | {:error, term()}
  def register_component(id, module, metadata \\ %{}) do
    GenServer.call(__MODULE__, {:register_component, id, module, metadata})
  end

  @doc """
  Unregister a component from discovery
  """
  @spec unregister_component(atom()) :: :ok
  def unregister_component(id) do
    GenServer.call(__MODULE__, {:unregister_component, id})
  end

  @doc """
  Find components matching a pattern
  """
  @spec find_components(discovery_pattern()) :: [component_match()]
  def find_components(pattern) do
    GenServer.call(__MODULE__, {:find_components, pattern})
  end

  @doc """
  Find components by capability requirements
  """
  @spec find_by_capabilities([term()]) :: [component_match()]
  def find_by_capabilities(required_capabilities) do
    pattern = %{capabilities: required_capabilities}
    find_components(pattern)
  end

  @doc """
  Find components by type
  """
  @spec find_by_type(atom()) :: [component_match()]
  def find_by_type(component_type) do
    pattern = %{type: component_type}
    find_components(pattern)
  end

  @doc """
  Find healthy components only
  """
  @spec find_healthy_components(discovery_pattern()) :: [component_match()]
  def find_healthy_components(pattern \\ %{}) do
    health_pattern = Map.put(pattern, :health, :healthy)
    find_components(health_pattern)
  end

  @doc """
  Get best component match using load balancing
  """
  @spec get_best_match(discovery_pattern(), atom()) :: component_match() | nil
  def get_best_match(pattern, strategy \\ :round_robin) do
    GenServer.call(__MODULE__, {:get_best_match, pattern, strategy})
  end

  @doc """
  Get component metadata
  """
  @spec get_component_metadata(atom()) :: map() | nil
  def get_component_metadata(id) do
    GenServer.call(__MODULE__, {:get_component_metadata, id})
  end

  @doc """
  Update component metadata
  """
  @spec update_component_metadata(atom(), map()) :: :ok | {:error, term()}
  def update_component_metadata(id, metadata) do
    GenServer.call(__MODULE__, {:update_component_metadata, id, metadata})
  end

  @doc """
  Get component health with caching
  """
  @spec get_component_health(atom()) :: :healthy | :unhealthy | :degraded | :unknown
  def get_component_health(id) do
    GenServer.call(__MODULE__, {:get_component_health, id})
  end

  @doc """
  Refresh health cache for all components
  """
  @spec refresh_health_cache() :: :ok
  def refresh_health_cache() do
    GenServer.cast(__MODULE__, :refresh_health_cache)
  end

  # GenServer callbacks

  def handle_call({:register_component, id, module, metadata}, _from, state) do
    enhanced_metadata = enhance_component_metadata(module, metadata)

    new_components = Map.put(state.components, id, %{
      id: id,
      module: module,
      metadata: enhanced_metadata,
      registered_at: System.system_time(:millisecond)
    })

    new_state = %{state | components: new_components}
    {:reply, :ok, new_state}
  end

  def handle_call({:unregister_component, id}, _from, state) do
    new_components = Map.delete(state.components, id)
    new_health_cache = Map.delete(state.health_cache, id)
    new_load_balancer_state = Map.delete(state.load_balancer_state, id)

    new_state = %{state |
      components: new_components,
      health_cache: new_health_cache,
      load_balancer_state: new_load_balancer_state
    }

    {:reply, :ok, new_state}
  end

  def handle_call({:find_components, pattern}, _from, state) do
    matches = find_matching_components(pattern, state.components)
    scored_matches = score_matches(matches, pattern)
    sorted_matches = Enum.sort_by(scored_matches, & &1.score, :desc)

    {:reply, sorted_matches, state}
  end

  def handle_call({:get_best_match, pattern, strategy}, _from, state) do
    matches = find_matching_components(pattern, state.components)

    case matches do
      [] -> {:reply, nil, state}
      _ ->
        {selected, new_lb_state} = apply_load_balancing(matches, strategy, state.load_balancer_state)
        new_state = %{state | load_balancer_state: new_lb_state}
        {:reply, selected, new_state}
    end
  end

  def handle_call({:get_component_metadata, id}, _from, state) do
    metadata = case Map.get(state.components, id) do
      nil -> nil
      component -> component.metadata
    end
    {:reply, metadata, state}
  end

  def handle_call({:update_component_metadata, id, metadata}, _from, state) do
    case Map.get(state.components, id) do
      nil ->
        {:reply, {:error, :component_not_registered}, state}

      component ->
        updated_component = %{component | metadata: Map.merge(component.metadata, metadata)}
        new_components = Map.put(state.components, id, updated_component)
        new_state = %{state | components: new_components}
        {:reply, :ok, new_state}
    end
  end

  def handle_call({:get_component_health, id}, _from, state) do
    health = get_cached_health(id, state)
    {:reply, health, state}
  end

  def handle_cast(:refresh_health_cache, state) do
    new_health_cache = refresh_all_health_checks(state.components)
    new_state = %{state | health_cache: new_health_cache}
    {:noreply, new_state}
  end

  def handle_info(:health_cache_cleanup, state) do
    current_time = System.system_time(:millisecond)

    new_health_cache = Map.filter(state.health_cache, fn {_id, {_health, timestamp}} ->
      current_time - timestamp < state.cache_ttl
    end)

    # Schedule next cleanup
    Process.send_after(self(), :health_cache_cleanup, state.cache_ttl)

    {:noreply, %{state | health_cache: new_health_cache}}
  end

  # Private functions

  defp enhance_component_metadata(module, metadata) do
    interface_metadata = PacketFlow.Component.Interface.get_interface_metadata(module)

    base_metadata = %{
      type: get_component_type(module),
      version: get_component_version(module),
      capabilities: get_component_capabilities(module),
      dependencies: get_component_dependencies(module),
      tags: get_component_tags(module),
      interface: interface_metadata
    }

    Map.merge(base_metadata, metadata)
  end

  defp get_component_type(module) do
    cond do
      function_exported?(module, :get_component_type, 0) -> module.get_component_type()
      String.contains?(to_string(module), "Reactor") -> :reactor
      String.contains?(to_string(module), "Capability") -> :capability
      String.contains?(to_string(module), "Context") -> :context
      String.contains?(to_string(module), "Intent") -> :intent
      String.contains?(to_string(module), "Stream") -> :stream
      String.contains?(to_string(module), "Temporal") -> :temporal
      String.contains?(to_string(module), "Web") -> :web
      true -> :generic
    end
  end

  defp get_component_version(module) do
    if function_exported?(module, :get_component_version, 0) do
      module.get_component_version()
    else
      "1.0.0"
    end
  end

  defp get_component_capabilities(module) do
    cond do
      function_exported?(module, :get_provided_capabilities, 0) ->
        module.get_provided_capabilities()
      function_exported?(module, :get_required_capabilities, 0) ->
        module.get_required_capabilities()
      true -> []
    end
  end

  defp get_component_dependencies(module) do
    if function_exported?(module, :get_dependencies, 0) do
      module.get_dependencies()
    else
      []
    end
  end

  defp get_component_tags(module) do
    if function_exported?(module, :get_component_tags, 0) do
      module.get_component_tags()
    else
      []
    end
  end

  defp find_matching_components(pattern, components) do
    Enum.filter(components, fn {_id, component} ->
      matches_pattern?(component, pattern)
    end)
    |> Enum.map(fn {id, component} ->
      %{
        id: id,
        module: component.module,
        metadata: component.metadata,
        score: 0.0
      }
    end)
  end

  defp matches_pattern?(component, pattern) do
    pattern
    |> Enum.all?(fn {key, value} ->
      case {key, value} do
        {:name, :any} -> true
        {:name, name} -> String.contains?(to_string(component.module), name)
        {:type, :any} -> true
        {:type, type} -> component.metadata.type == type
        {:capabilities, :any} -> true
        {:capabilities, required} -> has_capabilities?(component.metadata.capabilities, required)
        {:version, :any} -> true
        {:version, version} -> component.metadata.version == version
        {:health, :any} -> true
        {:health, health} -> get_component_health_direct(component.id, %{component.id => component}) == health
        {:tags, :any} -> true
        {:tags, tags} -> has_tags?(component.metadata.tags, tags)
        _ -> true
      end
    end)
  end

  defp has_capabilities?(provided, required) when is_list(provided) and is_list(required) do
    Enum.all?(required, fn req_cap ->
      Enum.any?(provided, fn prov_cap ->
        PacketFlow.Capability.Dynamic.implies?(prov_cap, req_cap)
      end)
    end)
  end
  defp has_capabilities?(_, _), do: false

  defp has_tags?(component_tags, required_tags) when is_list(component_tags) and is_list(required_tags) do
    Enum.all?(required_tags, fn tag -> tag in component_tags end)
  end
  defp has_tags?(_, _), do: false

  defp score_matches(matches, pattern) do
    Enum.map(matches, fn match ->
      score = calculate_match_score(match, pattern)
      %{match | score: score}
    end)
  end

  defp calculate_match_score(match, pattern) do
    base_score = 1.0

    # Bonus for exact type match
    type_bonus = if Map.get(pattern, :type) == match.metadata.type, do: 0.5, else: 0.0

    # Bonus for capability match
    capability_bonus = case Map.get(pattern, :capabilities) do
      :any -> 0.0
      nil -> 0.0
      required ->
        if has_capabilities?(match.metadata.capabilities, required), do: 1.0, else: -0.5
    end

    # Health bonus
    health_bonus = case get_component_health_direct(match.id, %{match.id => match}) do
      :healthy -> 0.3
      :degraded -> 0.0
      :unhealthy -> -1.0
      :unknown -> -0.2
    end

    # Version bonus (prefer newer versions)
    version_bonus = calculate_version_bonus(match.metadata.version)

    base_score + type_bonus + capability_bonus + health_bonus + version_bonus
  end

  defp calculate_version_bonus(version) do
    # Simple version scoring - higher versions get higher scores
    case Version.parse(version) do
      {:ok, %Version{major: major, minor: minor, patch: patch}} ->
        (major * 0.1) + (minor * 0.01) + (patch * 0.001)
      _ -> 0.0
    end
  end

  defp apply_load_balancing(matches, strategy, lb_state) do
    case strategy do
      :round_robin -> apply_round_robin(matches, lb_state)
      :least_connections -> apply_least_connections(matches, lb_state)
      :weighted_round_robin -> apply_weighted_round_robin(matches, lb_state)
      :random -> apply_random(matches, lb_state)
      _ -> apply_round_robin(matches, lb_state)
    end
  end

  defp apply_round_robin(matches, lb_state) do
    key = :round_robin_counter

    current_index = Map.get(lb_state, key, 0)
    selected_index = rem(current_index, length(matches))
    selected = Enum.at(matches, selected_index)

    new_lb_state = Map.put(lb_state, key, current_index + 1)

    {selected, new_lb_state}
  end

  defp apply_least_connections(matches, lb_state) do
    # Select the component with the least connections
    selected = Enum.min_by(matches, fn match ->
      Map.get(lb_state, {:connections, match.id}, 0)
    end)

    # Increment connection count
    connection_key = {:connections, selected.id}
    current_connections = Map.get(lb_state, connection_key, 0)
    new_lb_state = Map.put(lb_state, connection_key, current_connections + 1)

    {selected, new_lb_state}
  end

  defp apply_weighted_round_robin(matches, lb_state) do
    # Weight by match score
    total_weight = Enum.sum(Enum.map(matches, & &1.score))
    random_weight = :rand.uniform() * total_weight

    selected = select_by_weight(matches, random_weight, 0.0)
    {selected, lb_state}
  end

  defp apply_random(matches, lb_state) do
    selected = Enum.random(matches)
    {selected, lb_state}
  end

  defp select_by_weight([match | rest], target_weight, current_weight) do
    new_weight = current_weight + match.score
    if new_weight >= target_weight do
      match
    else
      select_by_weight(rest, target_weight, new_weight)
    end
  end
  defp select_by_weight([], _target_weight, _current_weight) do
    # Fallback to first match if something goes wrong
    nil
  end

  defp get_cached_health(id, state) do
    current_time = System.system_time(:millisecond)

    case Map.get(state.health_cache, id) do
      {health, timestamp} when current_time - timestamp < state.cache_ttl ->
        health
      _ ->
        # Cache miss or expired, get fresh health
        health = get_component_health_direct(id, state.components)
        # Note: We can't update state here in a handle_call,
        # so we return the health and let the caller decide
        health
    end
  end

  defp get_component_health_direct(id, components \\ %{}) do
    case Map.get(components, id) do
      nil ->
        # Fallback to process-based health check
        case Process.whereis(id) do
          nil -> :unknown
          pid ->
            try do
              if function_exported?(id, :health_check, 0) do
                apply(id, :health_check, [])
              else
                if Process.alive?(pid), do: :healthy, else: :unhealthy
              end
            rescue
              _ -> :unknown
            end
        end
      component ->
        # Use module-based health check
        try do
          if function_exported?(component.module, :health_check, 0) do
            apply(component.module, :health_check, [])
          else
            # Fallback to process check
            case Process.whereis(id) do
              nil -> :unknown
              pid -> if Process.alive?(pid), do: :healthy, else: :unhealthy
            end
          end
        rescue
          _ -> :unknown
        end
    end
  end

  defp refresh_all_health_checks(components) do
    current_time = System.system_time(:millisecond)

    Enum.reduce(components, %{}, fn {id, _component}, acc ->
      health = get_component_health_direct(id)
      Map.put(acc, id, {health, current_time})
    end)
  end
end
