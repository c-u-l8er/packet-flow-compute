defmodule PacketFlow.Capability.Dynamic do
  @moduledoc """
  Dynamic capability management and validation for PacketFlow.

  This module provides runtime capability creation, dynamic capability validation,
  capability composition patterns, capability delegation, and capability revocation.
  """

  @type capability :: any()
  @type capability_set :: MapSet.t(capability())
  @type capability_rule :: {capability(), list(capability())}
  @type capability_context :: map()

  # Runtime capability creation
  @doc """
  Creates a new capability at runtime with the given name and parameters.

  ## Examples
      iex> create_capability(:read, "/path/to/file")
      {:read, "/path/to/file"}

      iex> create_capability(:admin, "user123")
      {:admin, "user123"}
  """
  @spec create_capability(atom(), any()) :: capability()
  def create_capability(name, params \\ nil) do
    case params do
      nil -> {name}
      _ -> {name, params}
    end
  end

  @doc """
  Creates multiple capabilities at runtime.

  ## Examples
      iex> create_capabilities([:read, :write], "/path/to/file")
      [{:read, "/path/to/file"}, {:write, "/path/to/file"}]
  """
  @spec create_capabilities(list(atom()), any()) :: list(capability())
  def create_capabilities(names, params \\ nil) do
    Enum.map(names, &create_capability(&1, params))
  end

  # Dynamic capability validation
  @doc """
  Validates a capability against a set of available capabilities.

  ## Examples
      iex> validate_capability({:read, "/file"}, [{:read, "/file"}])
      true

      iex> validate_capability({:admin, "user"}, [{:read, "/file"}])
      false
  """
  @spec validate_capability(capability(), list(capability())) :: boolean()
  def validate_capability(capability, available_capabilities) do
    Enum.any?(available_capabilities, fn cap ->
      implies?(cap, capability)
    end)
  end

  @doc """
  Validates multiple capabilities against a set of available capabilities.

  ## Examples
      iex> validate_capabilities([{:read, "/file"}, {:write, "/file"}], [{:admin, "/file"}])
      true
  """
  @spec validate_capabilities(list(capability()), list(capability())) :: boolean()
  def validate_capabilities(required_capabilities, available_capabilities) do
    Enum.all?(required_capabilities, fn capability ->
      validate_capability(capability, available_capabilities)
    end)
  end

  # Capability composition patterns
  @doc """
  Composes multiple capabilities into a single capability set.

  ## Examples
      iex> compose_capabilities([{:read, "/file"}, {:write, "/file"}])
      #MapSet<[{:read, "/file"}, {:write, "/file"}]>
  """
  @spec compose_capabilities(list(capability())) :: capability_set()
  def compose_capabilities(capabilities) do
    MapSet.new(capabilities)
  end

  @doc """
  Merges multiple capability sets into a single set.

  ## Examples
      iex> merge_capability_sets([MapSet.new([{:read, "/file"}]), MapSet.new([{:write, "/file"}])])
      #MapSet<[{:read, "/file"}, {:write, "/file"}]>
  """
  @spec merge_capability_sets(list(capability_set())) :: capability_set()
  def merge_capability_sets(capability_sets) do
    Enum.reduce(capability_sets, MapSet.new(), fn set, acc ->
      MapSet.union(acc, set)
    end)
  end

  @doc """
  Filters capabilities based on a predicate function.

  ## Examples
      iex> filter_capabilities([{:read, "/file"}, {:write, "/file"}], fn {op, _} -> op == :read end)
      [{:read, "/file"}]
  """
  @spec filter_capabilities(list(capability()), (capability() -> boolean())) :: list(capability())
  def filter_capabilities(capabilities, predicate) do
    Enum.filter(capabilities, predicate)
  end

  # Capability delegation
  @doc """
  Delegates a capability from one entity to another.

  ## Examples
      iex> delegate_capability({:read, "/file"}, "user1", "user2")
      {:delegated, {:read, "/file"}, "user1", "user2"}
  """
  @spec delegate_capability(capability(), any(), any()) :: {:delegated, capability(), any(), any()}
  def delegate_capability(capability, from_entity, to_entity) do
    {:delegated, capability, from_entity, to_entity}
  end

  @doc """
  Delegates multiple capabilities from one entity to another.

  ## Examples
      iex> delegate_capabilities([{:read, "/file"}, {:write, "/file"}], "user1", "user2")
      [{:delegated, {:read, "/file"}, "user1", "user2"}, {:delegated, {:write, "/file"}, "user1", "user2"}]
  """
  @spec delegate_capabilities(list(capability()), any(), any()) :: list({:delegated, capability(), any(), any()})
  def delegate_capabilities(capabilities, from_entity, to_entity) do
    Enum.map(capabilities, fn capability ->
      delegate_capability(capability, from_entity, to_entity)
    end)
  end

  @doc """
  Validates a capability delegation.

  ## Examples
      iex> validate_delegation({:delegated, {:read, "/file"}, "user1", "user2"}, [{:admin, "/file"}])
      true
  """
  @spec validate_delegation({:delegated, capability(), any(), any()}, list(capability())) :: boolean()
  def validate_delegation({:delegated, capability, _from_entity, _to_entity}, available_capabilities) do
    validate_capability(capability, available_capabilities)
  end

  # Capability revocation
  @doc """
  Revokes a capability from an entity.

  ## Examples
      iex> revoke_capability({:read, "/file"}, "user1")
      {:revoked, {:read, "/file"}, "user1"}
  """
  @spec revoke_capability(capability(), any()) :: {:revoked, capability(), any()}
  def revoke_capability(capability, entity) do
    {:revoked, capability, entity}
  end

  @doc """
  Revokes multiple capabilities from an entity.

  ## Examples
      iex> revoke_capabilities([{:read, "/file"}, {:write, "/file"}], "user1")
      [{:revoked, {:read, "/file"}, "user1"}, {:revoked, {:write, "/file"}, "user1"}]
  """
  @spec revoke_capabilities(list(capability()), any()) :: list({:revoked, capability(), any()})
  def revoke_capabilities(capabilities, entity) do
    Enum.map(capabilities, fn capability ->
      revoke_capability(capability, entity)
    end)
  end

  # Capability inheritance patterns
  @doc """
  Creates a capability inheritance hierarchy.

  ## Examples
      iex> create_inheritance_hierarchy([{:admin, "/file"}, {:read, "/file"}, {:write, "/file"}])
      %{
        {:admin, "/file"} => [{:read, "/file"}, {:write, "/file"}],
        {:write, "/file"} => [{:read, "/file"}]
      }
  """
  @spec create_inheritance_hierarchy(list(capability())) :: map()
  def create_inheritance_hierarchy(capabilities) do
    # Simple inheritance based on capability names
    Enum.reduce(capabilities, %{}, fn capability, acc ->
      case capability do
        {name, _params} when name == :admin ->
          # Admin implies all other capabilities
          implied = Enum.filter(capabilities, fn {other_name, _} -> other_name != :admin end)
          Map.put(acc, capability, implied)
        {name, _params} when name == :write ->
          # Write implies read
          implied = Enum.filter(capabilities, fn {other_name, _} -> other_name == :read end)
          Map.put(acc, capability, implied)
        _ ->
          acc
      end
    end)
  end

  @doc """
  Checks if a capability inherits from another capability.

  ## Examples
      iex> inherits_from?({:admin, "/file"}, {:read, "/file"}, %{{:admin, "/file"} => [{:read, "/file"}]})
      true
  """
  @spec inherits_from?(capability(), capability(), map()) :: boolean()
  def inherits_from?(capability, parent_capability, hierarchy) do
    case Map.get(hierarchy, capability) do
      nil -> false
      implied_capabilities -> Enum.member?(implied_capabilities, parent_capability)
    end
  end

  # Utility functions
  @doc """
  Checks if one capability implies another capability.

  ## Examples
      iex> implies?({:admin, "/file"}, {:read, "/file"})
      true

      iex> implies?({:read, "/file"}, {:admin, "/file"})
      false
  """
  @spec implies?(capability(), capability()) :: boolean()
  def implies?(capability1, capability2) do
    case {capability1, capability2} do
      {cap1, cap2} when cap1 == cap2 -> true
      {{:admin, _}, {_op, _}} -> true
      {{:write, path}, {:read, path}} -> true
      {{:delete, path}, {:read, path}} -> true
      {{:delete, path}, {:write, path}} -> true
      _ -> false
    end
  end

  @doc """
  Gets all capabilities that are implied by a given capability.

  ## Examples
      iex> get_implied_capabilities({:admin, "/file"})
      [{:read, "/file"}, {:write, "/file"}, {:delete, "/file"}]
  """
  @spec get_implied_capabilities(capability()) :: list(capability())
  def get_implied_capabilities(capability) do
    case capability do
      {:admin, path} -> [{:read, path}, {:write, path}, {:delete, path}]
      {:write, path} -> [{:read, path}]
      {:delete, path} -> [{:read, path}, {:write, path}]
      _ -> []
    end
  end

  @doc """
  Validates a capability in a specific context.

  ## Examples
      iex> validate_capability_in_context({:read, "/file"}, %{user: "user1", time: ~U[2023-01-01 12:00:00Z]})
      true
  """
  @spec validate_capability_in_context(capability(), capability_context()) :: boolean()
  def validate_capability_in_context(_capability, context) do
    # Basic context validation - can be extended with more complex logic
    case context do
      %{time: time} when is_struct(time, DateTime) ->
        # Check if within business hours (9 AM to 5 PM UTC)
        hour = time.hour
        hour >= 9 and hour < 17
      _ ->
        true
    end
  end

  @doc """
  Creates a capability with temporal constraints.

  ## Examples
      iex> create_temporal_capability({:read, "/file"}, ~U[2023-01-01 12:00:00Z], ~U[2023-01-02 12:00:00Z])
      {:temporal, {:read, "/file"}, ~U[2023-01-01 12:00:00Z], ~U[2023-01-02 12:00:00Z]}
  """
  @spec create_temporal_capability(capability(), DateTime.t(), DateTime.t()) :: {:temporal, capability(), DateTime.t(), DateTime.t()}
  def create_temporal_capability(capability, valid_from, valid_until) do
    {:temporal, capability, valid_from, valid_until}
  end

  @doc """
  Validates a temporal capability at a specific time.

  ## Examples
      iex> validate_temporal_capability({:temporal, {:read, "/file"}, ~U[2023-01-01 12:00:00Z], ~U[2023-01-02 12:00:00Z]}, ~U[2023-01-01 15:00:00Z])
      true
  """
  @spec validate_temporal_capability({:temporal, capability(), DateTime.t(), DateTime.t()}, DateTime.t()) :: boolean()
  def validate_temporal_capability({:temporal, _capability, valid_from, valid_until}, current_time) do
    DateTime.compare(current_time, valid_from) in [:gt, :eq] and
    DateTime.compare(current_time, valid_until) == :lt
  end
end
