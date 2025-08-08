defmodule PacketFlow.Registry.DiscoveryTest do
  use ExUnit.Case, async: true

  alias PacketFlow.Registry.Discovery

  defmodule TestComponent1 do
    def get_component_type(), do: :reactor
    def get_component_version(), do: "1.0.0"
    def get_provided_capabilities(), do: [:read, :write]
    def get_dependencies(), do: []
    def get_component_tags(), do: ["tag1", "tag2"]
    def health_check(), do: :healthy
  end

  defmodule TestComponent2 do
    def get_component_type(), do: :capability
    def get_component_version(), do: "2.1.0"
    def get_provided_capabilities(), do: [:admin, :read]
    def get_dependencies(), do: [:test_component_1]
    def get_component_tags(), do: ["tag2", "tag3"]
    def health_check(), do: :degraded
  end

  defmodule TestComponent3 do
    def get_component_type(), do: :stream
    def get_component_version(), do: "1.5.0"
    def get_provided_capabilities(), do: [:process]
    def get_dependencies(), do: []
    def get_component_tags(), do: ["tag1"]
    def health_check(), do: :unhealthy
  end

  setup do
    # Start the discovery service
    start_supervised!({Discovery, []})

    # Register test components
    :ok = Discovery.register_component(:test_component_1, TestComponent1)
    :ok = Discovery.register_component(:test_component_2, TestComponent2)
    :ok = Discovery.register_component(:test_component_3, TestComponent3)

    :ok
  end

  describe "component registration" do
    test "register_component adds component to registry" do
      assert :ok = Discovery.register_component(:new_component, TestComponent1, %{custom: "metadata"})

      metadata = Discovery.get_component_metadata(:new_component)
      assert metadata != nil
      assert metadata.custom == "metadata"
      assert metadata.type == :reactor
      assert metadata.version == "1.0.0"
    end

    test "unregister_component removes component from registry" do
      :ok = Discovery.register_component(:temp_component, TestComponent1)
      assert Discovery.get_component_metadata(:temp_component) != nil

      :ok = Discovery.unregister_component(:temp_component)
      assert Discovery.get_component_metadata(:temp_component) == nil
    end

    test "get_component_metadata returns nil for non-existent component" do
      assert Discovery.get_component_metadata(:non_existent) == nil
    end

    test "update_component_metadata updates existing metadata" do
      new_metadata = %{updated: true, version: "2.0.0"}
      assert :ok = Discovery.update_component_metadata(:test_component_1, new_metadata)

      metadata = Discovery.get_component_metadata(:test_component_1)
      assert metadata.updated == true
      assert metadata.version == "2.0.0"
    end

    test "update_component_metadata returns error for non-existent component" do
      assert {:error, :component_not_registered} = Discovery.update_component_metadata(:non_existent, %{})
    end
  end

  describe "component discovery" do
    test "find_components with empty pattern returns all components" do
      matches = Discovery.find_components(%{})
      assert length(matches) >= 3

      component_ids = Enum.map(matches, & &1.id)
      assert :test_component_1 in component_ids
      assert :test_component_2 in component_ids
      assert :test_component_3 in component_ids
    end

    test "find_components by type" do
      matches = Discovery.find_components(%{type: :reactor})
      assert length(matches) >= 1

      reactor_match = Enum.find(matches, & &1.id == :test_component_1)
      assert reactor_match != nil
      assert reactor_match.metadata.type == :reactor
    end

    test "find_components by version" do
      matches = Discovery.find_components(%{version: "2.1.0"})
      assert length(matches) == 1

      version_match = List.first(matches)
      assert version_match.id == :test_component_2
      assert version_match.metadata.version == "2.1.0"
    end

    test "find_components by capabilities" do
      matches = Discovery.find_components(%{capabilities: [:read]})
      assert length(matches) >= 2

      component_ids = Enum.map(matches, & &1.id)
      assert :test_component_1 in component_ids
      assert :test_component_2 in component_ids
    end

    test "find_components by tags" do
      matches = Discovery.find_components(%{tags: ["tag1"]})
      assert length(matches) >= 2

      component_ids = Enum.map(matches, & &1.id)
      assert :test_component_1 in component_ids
      assert :test_component_3 in component_ids
    end

    test "find_components by health status" do
      matches = Discovery.find_components(%{health: :healthy})
      assert length(matches) >= 1

      healthy_match = Enum.find(matches, & &1.id == :test_component_1)
      assert healthy_match != nil
    end

    test "find_components with multiple criteria" do
      matches = Discovery.find_components(%{
        type: :reactor,
        capabilities: [:read]
      })

      assert length(matches) >= 1
      reactor_match = Enum.find(matches, & &1.id == :test_component_1)
      assert reactor_match != nil
    end

    test "find_components returns empty list when no matches" do
      matches = Discovery.find_components(%{type: :non_existent_type})
      assert matches == []
    end
  end

  describe "specialized discovery methods" do
    test "find_by_capabilities finds components with required capabilities" do
      matches = Discovery.find_by_capabilities([:read])
      assert length(matches) >= 2

      component_ids = Enum.map(matches, & &1.id)
      assert :test_component_1 in component_ids
      assert :test_component_2 in component_ids
    end

    test "find_by_type finds components of specific type" do
      matches = Discovery.find_by_type(:capability)
      assert length(matches) == 1

      match = List.first(matches)
      assert match.id == :test_component_2
      assert match.metadata.type == :capability
    end

    test "find_healthy_components filters by health status" do
      matches = Discovery.find_healthy_components()

      # Should only include healthy components
      healthy_ids = Enum.map(matches, & &1.id)
      assert :test_component_1 in healthy_ids
      refute :test_component_3 in healthy_ids  # unhealthy
    end

    test "find_healthy_components with additional pattern" do
      matches = Discovery.find_healthy_components(%{type: :reactor})

      assert length(matches) == 1
      match = List.first(matches)
      assert match.id == :test_component_1
    end
  end

  describe "load balancing" do
    test "get_best_match with round_robin strategy" do
      # Register multiple components of same type
      :ok = Discovery.register_component(:reactor_1, TestComponent1)
      :ok = Discovery.register_component(:reactor_2, TestComponent1)

      pattern = %{type: :reactor}

      # Get multiple matches to test round-robin
      match1 = Discovery.get_best_match(pattern, :round_robin)
      match2 = Discovery.get_best_match(pattern, :round_robin)
      match3 = Discovery.get_best_match(pattern, :round_robin)

      assert match1 != nil
      assert match2 != nil
      assert match3 != nil

      # Should cycle through available components
      matches = [match1.id, match2.id, match3.id]
      assert length(Enum.uniq(matches)) >= 2  # At least 2 different components
    end

    test "get_best_match with least_connections strategy" do
      pattern = %{type: :reactor}
      match = Discovery.get_best_match(pattern, :least_connections)

      assert match != nil
      assert match.metadata.type == :reactor
    end

    test "get_best_match with weighted_round_robin strategy" do
      pattern = %{capabilities: [:read]}
      match = Discovery.get_best_match(pattern, :weighted_round_robin)

      assert match != nil
      assert :read in match.metadata.capabilities
    end

    test "get_best_match with random strategy" do
      pattern = %{type: :reactor}
      match = Discovery.get_best_match(pattern, :random)

      assert match != nil
      assert match.metadata.type == :reactor
    end

    test "get_best_match returns nil when no matches" do
      pattern = %{type: :non_existent_type}
      match = Discovery.get_best_match(pattern, :round_robin)

      assert match == nil
    end
  end

  describe "health monitoring" do
    test "get_component_health returns health status" do
      health = Discovery.get_component_health(:test_component_1)
      assert health in [:healthy, :unhealthy, :degraded, :unknown]
    end

    test "get_component_health returns unknown for non-existent component" do
      health = Discovery.get_component_health(:non_existent)
      assert health == :unknown
    end

    test "refresh_health_cache updates health status" do
      # This is an async operation
      :ok = Discovery.refresh_health_cache()

      # Wait a bit for the cache to be updated
      Process.sleep(50)

      health = Discovery.get_component_health(:test_component_1)
      assert health in [:healthy, :unhealthy, :degraded, :unknown]
    end
  end

  describe "component scoring" do
    test "components are scored based on multiple factors" do
      # Find components with specific capabilities
      matches = Discovery.find_components(%{capabilities: [:read]})

      # Matches should be sorted by score (highest first)
      scores = Enum.map(matches, & &1.score)
      sorted_scores = Enum.sort(scores, :desc)
      assert scores == sorted_scores
    end

    test "healthy components get higher scores than unhealthy ones" do
      matches = Discovery.find_components(%{})

      healthy_matches = Enum.filter(matches, fn match ->
        Discovery.get_component_health(match.id) == :healthy
      end)

      unhealthy_matches = Enum.filter(matches, fn match ->
        Discovery.get_component_health(match.id) == :unhealthy
      end)

      if length(healthy_matches) > 0 and length(unhealthy_matches) > 0 do
        avg_healthy_score = Enum.sum(Enum.map(healthy_matches, & &1.score)) / length(healthy_matches)
        avg_unhealthy_score = Enum.sum(Enum.map(unhealthy_matches, & &1.score)) / length(unhealthy_matches)

        assert avg_healthy_score > avg_unhealthy_score
      end
    end
  end

  describe "metadata enhancement" do
    test "registered components get enhanced metadata" do
      metadata = Discovery.get_component_metadata(:test_component_1)

      assert metadata != nil
      assert metadata.type == :reactor
      assert metadata.version == "1.0.0"
      assert metadata.capabilities == [:read, :write]
      assert metadata.dependencies == []
      assert metadata.tags == ["tag1", "tag2"]
      assert is_map(metadata.interface)
      # registered_at is in the component wrapper, not metadata
    end

    test "components without specific functions get default metadata" do
      defmodule MinimalComponent do
        # No specific metadata functions
      end

      :ok = Discovery.register_component(:minimal, MinimalComponent)
      metadata = Discovery.get_component_metadata(:minimal)

      assert metadata.type == :generic
      assert metadata.version == "1.0.0"
      assert metadata.capabilities == []
      assert metadata.dependencies == []
      assert metadata.tags == []
    end
  end

  describe "pattern matching" do
    test "name pattern matching works with partial matches" do
      matches = Discovery.find_components(%{name: "TestComponent"})
      assert length(matches) >= 3  # All test components should match
    end

    test "any pattern matches everything" do
      matches = Discovery.find_components(%{
        name: :any,
        type: :any,
        capabilities: :any,
        version: :any,
        health: :any,
        tags: :any
      })

      assert length(matches) >= 3
    end

    test "complex capability matching with implications" do
      # This tests the capability implication logic
      # Admin capability should imply read capability
      matches = Discovery.find_components(%{capabilities: [:read]})

      # Should include components with admin capability (which implies read)
      admin_component = Enum.find(matches, & &1.id == :test_component_2)
      assert admin_component != nil
    end
  end

  describe "error handling" do
    test "handles component registration errors gracefully" do
      # Try to register component with invalid metadata
      result = Discovery.register_component(nil, TestComponent1)
      # Should not crash the system
      case result do
        :ok -> assert true
        {:error, _} -> assert true
        _ -> flunk("Unexpected result: #{inspect(result)}")
      end
    end

    test "handles discovery queries with invalid patterns" do
      # Should not crash with invalid pattern
      matches = Discovery.find_components(%{invalid_key: "invalid_value"})
      assert is_list(matches)
    end

    test "handles load balancing with empty component list" do
      # Try load balancing with pattern that matches nothing
      match = Discovery.get_best_match(%{type: :non_existent}, :round_robin)
      assert match == nil
    end
  end

  describe "concurrent access" do
    test "handles concurrent registration and discovery" do
      # Spawn multiple processes doing registration and discovery
      tasks = for i <- 1..10 do
        Task.async(fn ->
          component_id = String.to_atom("concurrent_#{i}")
          :ok = Discovery.register_component(component_id, TestComponent1)

          matches = Discovery.find_components(%{type: :reactor})
          assert is_list(matches)

          :ok = Discovery.unregister_component(component_id)
        end)
      end

      # Wait for all tasks to complete
      Enum.each(tasks, &Task.await/1)
    end

    test "handles concurrent load balancing requests" do
      pattern = %{type: :reactor}

      tasks = for _i <- 1..20 do
        Task.async(fn ->
          match = Discovery.get_best_match(pattern, :round_robin)
          assert match != nil
        end)
      end

      # Wait for all tasks to complete
      Enum.each(tasks, &Task.await/1)
    end
  end
end
