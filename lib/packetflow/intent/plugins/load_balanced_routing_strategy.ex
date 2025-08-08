defmodule PacketFlow.Intent.Plugins.LoadBalancedRoutingStrategy do
  @moduledoc """
  Load-balanced routing strategy for intent system

  This demonstrates a custom routing strategy that distributes intents
  across multiple processors using different load balancing algorithms.
  """

  @behaviour PacketFlow.Intent.Plugin.RoutingStrategy

  @strategy_type :load_balanced
  @targets [:reactor1, :reactor2, :reactor3, :reactor4]

  @doc """
  Route intents using load balancing
  """
  def route(intent, available_targets) do
    case get_load_balancing_algorithm(intent) do
      :round_robin ->
        round_robin_route(available_targets)
      :least_connections ->
        least_connections_route(available_targets)
      :weighted ->
        weighted_route(available_targets, intent)
      :ip_hash ->
        ip_hash_route(available_targets, intent)
      _ ->
        round_robin_route(available_targets)
    end
  end

  @doc """
  Get strategy type
  """
  def strategy_type do
    @strategy_type
  end

  @doc """
  Get default targets
  """
  def targets do
    @targets
  end

  # Private Functions

  defp get_load_balancing_algorithm(intent) do
    # Determine algorithm based on intent type or metadata
    case intent.type do
      "FileReadIntent" ->
        :round_robin
      "FileWriteIntent" ->
        :least_connections
      "UserIntent" ->
        :weighted
      "BatchIntent" ->
        :ip_hash
      _ ->
        :round_robin
    end
  end

  defp round_robin_route(available_targets) do
    case available_targets do
      [] ->
        {:error, :no_available_targets}
      targets ->
        # Simple round-robin using process dictionary
        current_index = get_current_round_robin_index()
        target = Enum.at(targets, rem(current_index, length(targets)))
        set_current_round_robin_index(current_index + 1)
        {:ok, target}
    end
  end

  defp least_connections_route(available_targets) do
    case available_targets do
      [] ->
        {:error, :no_available_targets}
      targets ->
        # Find target with least active connections
        target_with_least_connections = Enum.min_by(targets, &get_connection_count/1)
        {:ok, target_with_least_connections}
    end
  end

  defp weighted_route(available_targets, intent) do
    case available_targets do
      [] ->
        {:error, :no_available_targets}
      targets ->
        # Weighted routing based on intent priority and target capacity
        weights = calculate_weights(targets, intent)
        selected_target = weighted_random_selection(targets, weights)
        {:ok, selected_target}
    end
  end

  defp ip_hash_route(available_targets, intent) do
    case available_targets do
      [] ->
        {:error, :no_available_targets}
      targets ->
        # Hash-based routing for consistent assignment
        hash = calculate_ip_hash(intent)
        target_index = rem(hash, length(targets))
        target = Enum.at(targets, target_index)
        {:ok, target}
    end
  end

  defp get_current_round_robin_index do
    Process.get(:round_robin_index, 0)
  end

  defp set_current_round_robin_index(index) do
    Process.put(:round_robin_index, index)
  end

  defp get_connection_count(_target) do
    # In a real application, this would query the target's connection count
    # For now, return a random number to simulate different loads
    :rand.uniform(100)
  end

  defp calculate_weights(targets, intent) do
    # Calculate weights based on target capacity and intent priority
    Enum.map(targets, fn target ->
      base_weight = get_target_capacity(target)
      priority_multiplier = get_intent_priority_multiplier(intent)
      base_weight * priority_multiplier
    end)
  end

  defp get_target_capacity(_target) do
    # In a real application, this would query the target's capacity
    # For now, return a random capacity
    :rand.uniform(100)
  end

  defp get_intent_priority_multiplier(intent) do
    # Get priority multiplier based on intent type
    case intent.type do
      "HighPriorityIntent" -> 2.0
      "MediumPriorityIntent" -> 1.5
      "LowPriorityIntent" -> 1.0
      _ -> 1.0
    end
  end

  defp weighted_random_selection(targets, weights) do
    total_weight = Enum.sum(weights)
    random_value = :rand.uniform() * total_weight

    {selected_target, _} = Enum.reduce_while(
      Enum.zip(targets, weights),
      {nil, 0},
      fn {target, weight}, {_selected, cumulative_weight} ->
        new_cumulative = cumulative_weight + weight
        if random_value <= new_cumulative do
          {:halt, {target, new_cumulative}}
        else
          {:cont, {nil, new_cumulative}}
        end
      end
    )

    selected_target
  end

  defp calculate_ip_hash(intent) do
    # Calculate hash based on user_id or session_id
    ip_string = Map.get(intent.payload, :user_id, "default")
    :erlang.phash2(ip_string)
  end
end
