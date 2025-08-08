defmodule PacketFlow.Component.InterfaceTest do
  use ExUnit.Case, async: true

  alias PacketFlow.Component.Interface

  defmodule TestComponent do
    use GenServer
    use Interface

    def start_link(config) do
      GenServer.start_link(__MODULE__, config, name: __MODULE__)
    end

    def init(config) do
      {:ok, %{config: config, state: %{counter: 0}, started_at: System.system_time(:millisecond)}}
    end

    # Override some default implementations
    def get_dependencies(), do: [:dependency_1, :dependency_2]
    def get_required_capabilities(), do: [:read, :write]
    def get_provided_capabilities(), do: [:process, :transform]

    def handle_call(:get_state, _from, state), do: {:reply, state.state, state}
    def handle_call({:update_state, new_state}, _from, state), do: {:reply, :ok, %{state | state: new_state}}
    def handle_call(:get_config, _from, state), do: {:reply, state.config, state}
    def handle_call({:update_config, new_config}, _from, state), do: {:reply, :ok, %{state | config: new_config}}
    def handle_call(:get_started_time, _from, state), do: {:reply, {:ok, state.started_at}, state}
    def handle_call(:get_message_count, _from, state), do: {:reply, {:ok, 0}, state}

    def handle_info({:component_message, _from, _payload}, state) do
      {:noreply, state}
    end
  end

  defmodule MinimalComponent do
    @behaviour Interface

    # Only implement required callbacks
    def component_init(_config), do: {:ok, %{}}
    def get_state(), do: %{}
    def update_state(_new_state), do: :ok
    def health_check(), do: :healthy
    def get_dependencies(), do: []
    def validate_dependencies(), do: :ok
    def get_required_capabilities(), do: []
    def get_provided_capabilities(), do: []
  end

  defmodule BrokenComponent do
    # Missing required callbacks
  end

  setup do
    # Start the test component if not already running
    case GenServer.whereis(TestComponent) do
      nil ->
        {:ok, _pid} = TestComponent.start_link(%{test: true})
      _pid ->
        :ok
    end

    :ok
  end

  describe "interface validation" do
    test "validates complete component interface" do
      assert :ok = Interface.validate_component_interface(TestComponent)
    end

    test "validates minimal component interface" do
      assert :ok = Interface.validate_component_interface(MinimalComponent)
    end

    test "rejects component with missing required functions" do
      assert {:error, {:missing_functions, missing}} = Interface.validate_component_interface(BrokenComponent)
      assert {:component_init, 1} in missing
      assert {:get_state, 0} in missing
      assert {:update_state, 1} in missing
      assert {:health_check, 0} in missing
    end
  end

  describe "component lifecycle" do
    test "component_init returns proper state structure" do
      config = %{setting: "value"}
      assert {:ok, state} = TestComponent.component_init(config)
      assert %{config: ^config, state: %{}, started_at: _} = state
    end

    test "start_component starts the component process" do
      # Stop existing component first
      if pid = GenServer.whereis(TestComponent), do: GenServer.stop(pid)

      config = %{test: "config"}
      assert {:ok, pid} = TestComponent.start_component(config)
      assert Process.alive?(pid)
      assert pid == GenServer.whereis(TestComponent)

      # Cleanup
      GenServer.stop(pid)
    end

    test "stop_component stops the component process" do
      # Ensure component is running
      if GenServer.whereis(TestComponent) == nil do
        {:ok, _pid} = TestComponent.start_link(%{test: true})
      end

      assert :ok = TestComponent.stop_component()

      # Wait a bit for the process to stop
      Process.sleep(50)
      assert nil == GenServer.whereis(TestComponent)

      # Restart for other tests
      {:ok, _pid} = TestComponent.start_link(%{test: true})
    end
  end

  describe "state management" do
    test "get_state returns current state" do
      state = TestComponent.get_state()
      assert is_map(state)
      assert Map.has_key?(state, :counter)
    end

    test "update_state updates component state" do
      new_state = %{counter: 42, data: "test"}
      assert :ok = TestComponent.update_state(new_state)

      updated_state = TestComponent.get_state()
      assert updated_state == new_state
    end
  end

  describe "configuration management" do
    test "get_config returns current configuration" do
      config = TestComponent.get_config()
      assert is_map(config)
      assert Map.has_key?(config, :test)
    end

    test "update_config updates component configuration" do
      new_config = %{new_setting: "new_value", another: 123}
      assert :ok = TestComponent.update_config(new_config)

      updated_config = TestComponent.get_config()
      assert updated_config == new_config
    end
  end

  describe "health monitoring" do
    test "health_check returns healthy for running component" do
      assert :healthy = TestComponent.health_check()
    end

    test "health_check returns unhealthy for non-existent component" do
      # Test with a non-existent component
      defmodule NonExistentComponent do
        use Interface
      end

      assert :unhealthy = NonExistentComponent.health_check()
    end
  end

  describe "metrics collection" do
    test "get_metrics returns component metrics" do
      metrics = TestComponent.get_metrics()

      assert is_map(metrics)
      assert Map.has_key?(metrics, :component)
      assert Map.has_key?(metrics, :health)
      assert Map.has_key?(metrics, :uptime)
      assert Map.has_key?(metrics, :message_count)

      assert metrics.component == TestComponent
      assert metrics.health == :healthy
      assert is_number(metrics.uptime)
      assert is_integer(metrics.message_count)
    end
  end

  describe "dependency management" do
    test "get_dependencies returns component dependencies" do
      dependencies = TestComponent.get_dependencies()
      assert dependencies == [:dependency_1, :dependency_2]
    end

    test "validate_dependencies checks dependency availability" do
      # This will fail because dependencies don't exist
      assert {:error, missing} = TestComponent.validate_dependencies()
      assert :dependency_1 in missing
      assert :dependency_2 in missing
    end

    test "validate_dependencies succeeds when dependencies exist" do
      # Test with minimal component that has no dependencies
      assert :ok = MinimalComponent.validate_dependencies()
    end
  end

  describe "capability management" do
    test "get_required_capabilities returns required capabilities" do
      capabilities = TestComponent.get_required_capabilities()
      assert capabilities == [:read, :write]
    end

    test "get_provided_capabilities returns provided capabilities" do
      capabilities = TestComponent.get_provided_capabilities()
      assert capabilities == [:process, :transform]
    end
  end

  describe "message handling" do
    test "send_message sends message to target component" do
      # Send message to self (TestComponent)
      assert :ok = TestComponent.send_message(TestComponent, {:test, "payload"})
    end

    test "send_message returns error for non-existent target" do
      assert {:error, :target_not_found} = TestComponent.send_message(:non_existent, "payload")
    end

    test "handle_message provides default implementation" do
      state = %{data: "test"}
      assert {:ok, ^state} = TestComponent.handle_message("test message", state)
    end
  end

  describe "interface metadata" do
    test "get_interface_metadata returns component metadata" do
      metadata = Interface.get_interface_metadata(TestComponent)

      assert is_map(metadata)
      assert metadata.module == TestComponent
      assert is_list(metadata.behaviours)
      assert is_list(metadata.functions)
      assert metadata.implements_component_interface == true

      # Check that interface implementation is detected (behaviour might not show in module_info)
      assert metadata.implements_component_interface == true
    end

    test "get_interface_metadata detects missing interface implementation" do
      metadata = Interface.get_interface_metadata(BrokenComponent)

      assert metadata.module == BrokenComponent
      assert metadata.implements_component_interface == false
    end
  end

  describe "default implementations" do
    test "default component_init creates proper state" do
      defmodule DefaultComponent do
        use Interface
      end

      config = %{test: "value"}
      assert {:ok, state} = DefaultComponent.component_init(config)
      assert %{config: ^config, state: %{}, started_at: _} = state
      assert is_integer(state.started_at)
    end

    test "default get_dependencies returns empty list" do
      defmodule DefaultComponent do
        use Interface
      end

      assert [] = DefaultComponent.get_dependencies()
    end

    test "default get_required_capabilities returns empty list" do
      defmodule DefaultComponent do
        use Interface
      end

      assert [] = DefaultComponent.get_required_capabilities()
    end

    test "default get_provided_capabilities returns empty list" do
      defmodule DefaultComponent do
        use Interface
      end

      assert [] = DefaultComponent.get_provided_capabilities()
    end

    test "default validate_dependencies returns ok for no dependencies" do
      defmodule DefaultComponent do
        use Interface
      end

      assert :ok = DefaultComponent.validate_dependencies()
    end
  end

  describe "interface using macro" do
    test "using macro adds all required functions" do
      defmodule MacroTestComponent do
        use Interface
      end

      # Check that all required functions are defined
      assert function_exported?(MacroTestComponent, :component_init, 1)
      assert function_exported?(MacroTestComponent, :get_state, 0)
      assert function_exported?(MacroTestComponent, :update_state, 1)
      assert function_exported?(MacroTestComponent, :send_message, 2)
      assert function_exported?(MacroTestComponent, :handle_message, 2)
      assert function_exported?(MacroTestComponent, :health_check, 0)
      assert function_exported?(MacroTestComponent, :get_metrics, 0)
      assert function_exported?(MacroTestComponent, :get_config, 0)
      assert function_exported?(MacroTestComponent, :update_config, 1)
      assert function_exported?(MacroTestComponent, :start_component, 1)
      assert function_exported?(MacroTestComponent, :stop_component, 0)
      assert function_exported?(MacroTestComponent, :get_dependencies, 0)
      assert function_exported?(MacroTestComponent, :validate_dependencies, 0)
      assert function_exported?(MacroTestComponent, :get_required_capabilities, 0)
      assert function_exported?(MacroTestComponent, :get_provided_capabilities, 0)
    end

    test "using macro makes functions overridable" do
      # This is tested implicitly by TestComponent overriding some functions
      assert TestComponent.get_dependencies() == [:dependency_1, :dependency_2]
      assert TestComponent.get_required_capabilities() == [:read, :write]
      assert TestComponent.get_provided_capabilities() == [:process, :transform]
    end
  end
end
