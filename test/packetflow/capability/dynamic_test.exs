defmodule PacketFlow.Capability.DynamicTest do
  use ExUnit.Case, async: true
  alias PacketFlow.Capability.Dynamic

  describe "runtime capability creation" do
    test "creates a capability with parameters" do
      capability = Dynamic.create_capability(:read, "/path/to/file")
      assert capability == {:read, "/path/to/file"}
    end

    test "creates a capability without parameters" do
      capability = Dynamic.create_capability(:admin)
      assert capability == {:admin}
    end

    test "creates multiple capabilities" do
      capabilities = Dynamic.create_capabilities([:read, :write], "/path/to/file")
      assert capabilities == [{:read, "/path/to/file"}, {:write, "/path/to/file"}]
    end
  end

  describe "dynamic capability validation" do
    test "validates a capability against available capabilities" do
      available = [{:read, "/file"}]
      assert Dynamic.validate_capability({:read, "/file"}, available) == true
      assert Dynamic.validate_capability({:admin, "user"}, available) == false
    end

    test "validates multiple capabilities" do
      available = [{:admin, "/file"}]
      required = [{:read, "/file"}, {:write, "/file"}]
      assert Dynamic.validate_capabilities(required, available) == true
    end

    test "validates capabilities with inheritance" do
      available = [{:admin, "/file"}]
      required = [{:read, "/file"}]
      assert Dynamic.validate_capabilities(required, available) == true
    end
  end

  describe "capability composition patterns" do
    test "composes capabilities into a set" do
      capabilities = [{:read, "/file"}, {:write, "/file"}]
      set = Dynamic.compose_capabilities(capabilities)
      assert MapSet.size(set) == 2
      assert MapSet.member?(set, {:read, "/file"})
      assert MapSet.member?(set, {:write, "/file"})
    end

    test "merges capability sets" do
      set1 = MapSet.new([{:read, "/file"}])
      set2 = MapSet.new([{:write, "/file"}])
      merged = Dynamic.merge_capability_sets([set1, set2])
      assert MapSet.size(merged) == 2
      assert MapSet.member?(merged, {:read, "/file"})
      assert MapSet.member?(merged, {:write, "/file"})
    end

    test "filters capabilities" do
      capabilities = [{:read, "/file"}, {:write, "/file"}]
      filtered = Dynamic.filter_capabilities(capabilities, fn {op, _} -> op == :read end)
      assert filtered == [{:read, "/file"}]
    end
  end

  describe "capability delegation" do
    test "delegates a capability" do
      delegation = Dynamic.delegate_capability({:read, "/file"}, "user1", "user2")
      assert delegation == {:delegated, {:read, "/file"}, "user1", "user2"}
    end

    test "delegates multiple capabilities" do
      capabilities = [{:read, "/file"}, {:write, "/file"}]
      delegations = Dynamic.delegate_capabilities(capabilities, "user1", "user2")
      assert length(delegations) == 2
      assert Enum.all?(delegations, fn delegation ->
        match?({:delegated, _, "user1", "user2"}, delegation)
      end)
    end

    test "validates a delegation" do
      delegation = {:delegated, {:read, "/file"}, "user1", "user2"}
      available = [{:admin, "/file"}]
      assert Dynamic.validate_delegation(delegation, available) == true
    end
  end

  describe "capability revocation" do
    test "revokes a capability" do
      revocation = Dynamic.revoke_capability({:read, "/file"}, "user1")
      assert revocation == {:revoked, {:read, "/file"}, "user1"}
    end

    test "revokes multiple capabilities" do
      capabilities = [{:read, "/file"}, {:write, "/file"}]
      revocations = Dynamic.revoke_capabilities(capabilities, "user1")
      assert length(revocations) == 2
      assert Enum.all?(revocations, fn revocation ->
        match?({:revoked, _, "user1"}, revocation)
      end)
    end
  end

  describe "capability inheritance patterns" do
    test "creates inheritance hierarchy" do
      capabilities = [{:admin, "/file"}, {:read, "/file"}, {:write, "/file"}]
      hierarchy = Dynamic.create_inheritance_hierarchy(capabilities)

      assert Map.has_key?(hierarchy, {:admin, "/file"})
      assert Map.has_key?(hierarchy, {:write, "/file"})

      admin_implied = hierarchy[{:admin, "/file"}]
      assert length(admin_implied) == 2
      assert Enum.member?(admin_implied, {:read, "/file"})
      assert Enum.member?(admin_implied, {:write, "/file"})
    end

    test "checks inheritance relationship" do
      hierarchy = %{
        {:admin, "/file"} => [{:read, "/file"}, {:write, "/file"}],
        {:write, "/file"} => [{:read, "/file"}]
      }

      assert Dynamic.inherits_from?({:admin, "/file"}, {:read, "/file"}, hierarchy) == true
      assert Dynamic.inherits_from?({:write, "/file"}, {:read, "/file"}, hierarchy) == true
      assert Dynamic.inherits_from?({:read, "/file"}, {:admin, "/file"}, hierarchy) == false
    end
  end

  describe "utility functions" do
    test "checks capability implications" do
      assert Dynamic.implies?({:admin, "/file"}, {:read, "/file"}) == true
      assert Dynamic.implies?({:write, "/file"}, {:read, "/file"}) == true
      assert Dynamic.implies?({:read, "/file"}, {:admin, "/file"}) == false
      assert Dynamic.implies?({:read, "/file"}, {:read, "/file"}) == true
    end

    test "gets implied capabilities" do
      implied = Dynamic.get_implied_capabilities({:admin, "/file"})
      assert length(implied) == 3
      assert Enum.member?(implied, {:read, "/file"})
      assert Enum.member?(implied, {:write, "/file"})
      assert Enum.member?(implied, {:delete, "/file"})
    end

    test "validates capability in context" do
      context = %{user: "user1", time: ~U[2023-01-01 12:00:00Z]}
      assert Dynamic.validate_capability_in_context({:read, "/file"}, context) == true

      context_after_hours = %{user: "user1", time: ~U[2023-01-01 20:00:00Z]}
      assert Dynamic.validate_capability_in_context({:read, "/file"}, context_after_hours) == false
    end
  end

  describe "temporal capabilities" do
    test "creates temporal capability" do
      capability = {:read, "/file"}
      valid_from = ~U[2023-01-01 12:00:00Z]
      valid_until = ~U[2023-01-02 12:00:00Z]

      temporal_cap = Dynamic.create_temporal_capability(capability, valid_from, valid_until)
      assert temporal_cap == {:temporal, capability, valid_from, valid_until}
    end

    test "validates temporal capability" do
      temporal_cap = {:temporal, {:read, "/file"}, ~U[2023-01-01 12:00:00Z], ~U[2023-01-02 12:00:00Z]}

      # Valid time
      assert Dynamic.validate_temporal_capability(temporal_cap, ~U[2023-01-01 15:00:00Z]) == true

      # Before valid time
      assert Dynamic.validate_temporal_capability(temporal_cap, ~U[2023-01-01 10:00:00Z]) == false

      # After valid time
      assert Dynamic.validate_temporal_capability(temporal_cap, ~U[2023-01-02 15:00:00Z]) == false
    end
  end
end
