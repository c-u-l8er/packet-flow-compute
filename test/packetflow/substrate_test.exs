defmodule PacketFlow.SubstrateTest do
  use ExUnit.Case
  use PacketFlow.Substrate.Interface

  alias PacketFlow.Substrate

  setup do
    # Start the substrate system for each test
    {:ok, _pid} = Substrate.start_link()
    :ok
  end

  describe "substrate registration" do
    test "register a substrate successfully" do
      config = %{enabled: true, priority: 5}
      result = Substrate.register_substrate(:test_substrate, PacketFlow.ADT, config)

      assert {:ok, substrate_info} = result
      assert substrate_info.id == :test_substrate
      assert substrate_info.module == PacketFlow.ADT
      assert substrate_info.config.enabled == true
      assert substrate_info.config.priority == 5
      assert substrate_info.status == :active
    end

    test "register substrate with dependencies" do
      # Register base substrate first
      {:ok, _} = Substrate.register_substrate(:base_substrate, PacketFlow.ADT, %{})

      # Register dependent substrate
      config = %{dependencies: [:base_substrate]}
      result = Substrate.register_substrate(:dependent_substrate, PacketFlow.Actor, config)

      assert {:ok, substrate_info} = result
      assert :base_substrate in substrate_info.dependencies
    end

    test "fail to register with invalid module" do
      result = Substrate.register_substrate(:invalid_substrate, :NonExistentModule, %{})
      assert {:error, "Module not found or not loaded"} = result
    end

    test "fail to register with invalid config" do
      result = Substrate.register_substrate(:invalid_substrate, PacketFlow.ADT, "invalid_config")
      assert {:error, "Invalid configuration format"} = result
    end
  end

  describe "substrate management" do
    setup do
      {:ok, _} = Substrate.register_substrate(:test_substrate, PacketFlow.ADT, %{})
      :ok
    end

    test "get substrate information" do
      substrate_info = Substrate.get_substrate_info(:test_substrate)

      assert substrate_info != nil
      assert substrate_info.id == :test_substrate
      assert substrate_info.module == PacketFlow.ADT
    end

    test "list all substrates" do
      substrates = Substrate.list_substrates()
      assert :test_substrate in substrates
    end

    test "update substrate configuration" do
      new_config = %{enabled: false, priority: 10}
      result = Substrate.update_substrate_config(:test_substrate, new_config)

      assert :ok = result

      substrate_info = Substrate.get_substrate_info(:test_substrate)
      assert substrate_info.config.enabled == false
      assert substrate_info.config.priority == 10
    end

    test "fail to update non-existent substrate" do
      result = Substrate.update_substrate_config(:non_existent, %{})
      assert {:error, "Substrate not found"} = result
    end
  end

  describe "substrate dependencies" do
    setup do
      {:ok, _} = Substrate.register_substrate(:base_substrate, PacketFlow.ADT, %{})
      {:ok, _} = Substrate.register_substrate(:dependent_substrate, PacketFlow.Actor, %{})
      :ok
    end

    test "add substrate dependency" do
      result = Substrate.add_substrate_dependency(:dependent_substrate, :base_substrate)
      assert :ok = result

      substrate_info = Substrate.get_substrate_info(:dependent_substrate)
      assert :base_substrate in substrate_info.dependencies
    end

    test "remove substrate dependency" do
      # Add dependency first
      Substrate.add_substrate_dependency(:dependent_substrate, :base_substrate)

      # Remove dependency
      result = Substrate.remove_substrate_dependency(:dependent_substrate, :base_substrate)
      assert :ok = result

      substrate_info = Substrate.get_substrate_info(:dependent_substrate)
      assert :base_substrate not in substrate_info.dependencies
    end

    test "fail to add dependency to non-existent substrate" do
      result = Substrate.add_substrate_dependency(:non_existent, :base_substrate)
      assert {:error, "Substrate not found"} = result
    end

    test "fail to add non-existent dependency" do
      result = Substrate.add_substrate_dependency(:dependent_substrate, :non_existent)
      assert {:error, "Dependency substrate not found"} = result
    end
  end

  describe "substrate composition" do
    setup do
      {:ok, _} = Substrate.register_substrate(:adt_substrate, PacketFlow.ADT, %{})
      {:ok, _} = Substrate.register_substrate(:actor_substrate, PacketFlow.Actor, %{})
      {:ok, _} = Substrate.register_substrate(:stream_substrate, PacketFlow.Stream, %{})
      :ok
    end

    test "create substrate composition" do
      substrate_ids = [:adt_substrate, :actor_substrate]
      config = %{name: "test_composition"}

      result = Substrate.create_composition("test_composition", substrate_ids, config)
      assert {:ok, "test_composition"} = result
    end

    test "fail to create composition with missing substrates" do
      substrate_ids = [:adt_substrate, :non_existent_substrate]

      result = Substrate.create_composition("invalid_composition", substrate_ids, %{})
      assert {:error, "Missing substrates: non_existent_substrate"} = result
    end

    test "load substrate composition" do
      # Create composition first
      substrate_ids = [:adt_substrate, :actor_substrate]
      Substrate.create_composition("test_composition", substrate_ids, %{})

      # Load composition
      result = Substrate.load_composition("test_composition")
      assert {:ok, module} = result
      assert is_atom(module)
    end

    test "fail to load non-existent composition" do
      result = Substrate.load_composition("non_existent_composition")
      assert {:error, "Composition not found"} = result
    end
  end

  describe "substrate health monitoring" do
    setup do
      {:ok, _} = Substrate.register_substrate(:test_substrate, PacketFlow.ADT, %{})
      :ok
    end

    test "get substrate health status" do
      health_status = Substrate.get_substrate_health(:test_substrate)

      assert health_status.id == :test_substrate
      assert health_status.status == :active
      assert is_float(health_status.load_factor)
      assert health_status.healthy == true
    end

    test "fail to get health for non-existent substrate" do
      result = Substrate.get_substrate_health(:non_existent)
      assert {:error, "Substrate not found"} = result
    end
  end

  describe "substrate watching" do
    setup do
      {:ok, _} = Substrate.register_substrate(:test_substrate, PacketFlow.ADT, %{})
      :ok
    end

    test "watch substrate for changes" do
      test_pid = self()
      result = Substrate.watch_substrate(:test_substrate, test_pid)
      assert :ok = result
    end

    test "unwatch substrate" do
      test_pid = self()
      Substrate.watch_substrate(:test_substrate, test_pid)

      result = Substrate.unwatch_substrate(:test_substrate, test_pid)
      assert :ok = result
    end

    test "fail to watch non-existent substrate" do
      result = Substrate.watch_substrate(:non_existent, self())
      assert {:error, "Substrate not found"} = result
    end
  end

  describe "substrate unregistration" do
    setup do
      {:ok, _} = Substrate.register_substrate(:base_substrate, PacketFlow.ADT, %{})
      {:ok, _} = Substrate.register_substrate(:dependent_substrate, PacketFlow.Actor, %{dependencies: [:base_substrate]})
      :ok
    end

    test "unregister substrate successfully" do
      # First remove the dependency
      Substrate.remove_substrate_dependency(:dependent_substrate, :base_substrate)

      result = Substrate.unregister_substrate(:base_substrate)
      assert :ok = result

      substrate_info = Substrate.get_substrate_info(:base_substrate)
      assert substrate_info == nil
    end

    test "fail to unregister substrate with dependencies" do
      result = Substrate.unregister_substrate(:base_substrate)
      assert {:error, "Cannot unregister: substrates depend on this substrate"} = result
    end

    test "fail to unregister non-existent substrate" do
      result = Substrate.unregister_substrate(:non_existent)
      assert {:error, "Substrate not found"} = result
    end
  end

  describe "substrate interface compliance" do
    test "substrate implements required interface" do
      # Test that our test module implements the interface
      assert {:ok, _} = init_substrate(%{test: true})
      assert %{status: :unknown} = get_health_status()
      assert [] = get_capabilities()
      assert has_capability(:test_capability) == false
      assert %{} = get_metrics()
      assert :ok = record_metric(:test_metric, 42)
      assert {:ok, _} = validate_config(%{test: true})
      assert {:ok, _} = validate_message(%{test: "message"})
      assert is_binary(serialize_state())
      assert {:ok, _} = deserialize_state(serialize_state())
      assert "1.0.0" = get_version()
      assert true = is_compatible_with("1.0.0")
      assert {:ok, []} = authenticate(%{})
      assert authorize(:test_permission, :test_resource) == false
      assert %{} = get_debug_info()
      assert :ok = set_debug_level(:info)
      assert [] = get_logs()
      assert {:ok, []} = optimize()
      assert %{} = get_performance_stats()
      assert [] = discover_peers()
      assert :ok = handle_failure(%{error: "test"})
      assert [] = get_failure_history()
      assert :ok = clear_failure_history()
      assert [] = get_scaling_recommendations()
      assert %{} = get_resource_usage()
      assert %{} = get_resource_limits()
      assert [] = get_time_constraints()
      assert true = is_within_time_constraints()
      assert [] = get_input_ports()
      assert [] = get_output_ports()
      assert %{} = get_state()
      assert :ok = send_notification(:test_event, %{data: "test"})
    end
  end

  describe "complex substrate scenarios" do
    test "full substrate lifecycle" do
      # Register multiple substrates
      {:ok, _} = Substrate.register_substrate(:adt, PacketFlow.ADT, %{priority: 1})
      {:ok, _} = Substrate.register_substrate(:actor, PacketFlow.Actor, %{priority: 2})
      {:ok, _} = Substrate.register_substrate(:stream, PacketFlow.Stream, %{priority: 3})
      {:ok, _} = Substrate.register_substrate(:temporal, PacketFlow.Temporal, %{priority: 4})

      # Create dependencies
      Substrate.add_substrate_dependency(:actor, :adt)
      Substrate.add_substrate_dependency(:stream, :actor)
      Substrate.add_substrate_dependency(:temporal, :stream)

      # Create composition
      {:ok, _} = Substrate.create_composition("full_stack", [:adt, :actor, :stream, :temporal], %{})

      # Verify all substrates are registered
      substrates = Substrate.list_substrates()
      assert length(substrates) == 4
      assert :adt in substrates
      assert :actor in substrates
      assert :stream in substrates
      assert :temporal in substrates

      # Verify dependencies
      actor_info = Substrate.get_substrate_info(:actor)
      assert :adt in actor_info.dependencies

      stream_info = Substrate.get_substrate_info(:stream)
      assert :actor in stream_info.dependencies

      temporal_info = Substrate.get_substrate_info(:temporal)
      assert :stream in temporal_info.dependencies

      # Load composition
      {:ok, composition_module} = Substrate.load_composition("full_stack")
      assert is_atom(composition_module)

      # Verify health status
      Enum.each(substrates, fn substrate_id ->
        health = Substrate.get_substrate_health(substrate_id)
        assert health.healthy == true
        assert health.status == :active
      end)
    end

    test "substrate configuration updates" do
      # Register substrate with initial config
      initial_config = %{enabled: true, priority: 5, timeout: 30000}
      {:ok, _} = Substrate.register_substrate(:config_test, PacketFlow.ADT, initial_config)

      # Update configuration
      updated_config = %{enabled: false, priority: 10, timeout: 60000}
      :ok = Substrate.update_substrate_config(:config_test, updated_config)

      # Verify configuration was updated
      substrate_info = Substrate.get_substrate_info(:config_test)
      assert substrate_info.config.enabled == false
      assert substrate_info.config.priority == 10
      assert substrate_info.config.timeout == 60000

      # Verify default values are preserved
      assert substrate_info.config.retry_count == 3
    end

    test "substrate watching and notifications" do
      # Register substrate
      {:ok, _} = Substrate.register_substrate(:watch_test, PacketFlow.ADT, %{})

      # Watch substrate
      test_pid = self()
      :ok = Substrate.watch_substrate(:watch_test, test_pid)

      # Update substrate (this would trigger notifications in a real implementation)
      :ok = Substrate.update_substrate_config(:watch_test, %{priority: 10})

      # Unwatch substrate
      :ok = Substrate.unwatch_substrate(:watch_test, test_pid)
    end
  end
end
