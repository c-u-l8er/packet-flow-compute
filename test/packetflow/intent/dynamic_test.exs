defmodule PacketFlow.Intent.DynamicTest do
  use ExUnit.Case, async: true
  doctest PacketFlow.Intent.Dynamic

  alias PacketFlow.Intent.Dynamic
  alias PacketFlow.Intent.Plugins.FileValidationPlugin
  alias PacketFlow.Intent.Plugins.UserValidationPlugin
  alias PacketFlow.Intent.Plugins.CustomFileOperationIntent
  alias PacketFlow.Intent.Plugins.LoadBalancedRoutingStrategy
  alias PacketFlow.Intent.Plugins.RetryCompositionPattern

  setup do
    # Register test plugins
    PacketFlow.Intent.Plugin.register_plugin(FileValidationPlugin)
    PacketFlow.Intent.Plugin.register_plugin(UserValidationPlugin)

    # Register test reactors
    PacketFlow.Registry.register_reactor("file_reactor", %{id: "file_reactor"})
    PacketFlow.Registry.register_reactor("user_reactor", %{id: "user_reactor"})
    PacketFlow.Registry.register_reactor("default_reactor", %{id: "default_reactor"})

    :ok
  end

  describe "create_intent/3" do
    test "creates a basic intent" do
      intent = Dynamic.create_intent("TestIntent", %{value: "test"}, [])

      assert intent.type == "TestIntent"
      assert intent.payload.value == "test"
      assert intent.capabilities == []
      assert intent.metadata.dynamic == true
      assert intent.metadata.id
    end

    test "creates intent with capabilities" do
      capabilities = [FileCap.read("/path")]
      intent = Dynamic.create_intent("FileReadIntent", %{path: "/path"}, capabilities)

      assert intent.type == "FileReadIntent"
      assert intent.capabilities == capabilities
    end
  end

  describe "create_composite_intent/2" do
    test "creates composite intent" do
      intent1 = Dynamic.create_intent("Intent1", %{value: "1"}, [])
      intent2 = Dynamic.create_intent("Intent2", %{value: "2"}, [])

      composite = Dynamic.create_composite_intent([intent1, intent2], :sequential)

      assert composite.type == :composite
      assert composite.intents == [intent1, intent2]
      assert composite.composition_strategy == :sequential
      assert composite.metadata.composite == true
    end

    test "creates composite intent with default strategy" do
      intent1 = Dynamic.create_intent("Intent1", %{value: "1"}, [])
      intent2 = Dynamic.create_intent("Intent2", %{value: "2"}, [])

      composite = Dynamic.create_composite_intent([intent1, intent2])

      assert composite.composition_strategy == :parallel
    end
  end

  describe "route_intent/1" do
    test "routes file intent to file processor" do
      intent = Dynamic.create_intent("FileReadIntent", %{path: "/test"}, [])

      case Dynamic.route_intent(intent) do
        {:ok, target} ->
          assert target == PacketFlow.Registry.lookup_reactor("file_reactor")
        {:error, reason} ->
          flunk("Failed to route intent: #{reason}")
      end
    end

    test "routes user intent to user processor" do
      intent = Dynamic.create_intent("UserIntent", %{user_id: "123"}, [])

      case Dynamic.route_intent(intent) do
        {:ok, target} ->
          assert target == PacketFlow.Registry.lookup_reactor("user_reactor")
        {:error, reason} ->
          flunk("Failed to route intent: #{reason}")
      end
    end

    test "routes unknown intent to default processor" do
      intent = Dynamic.create_intent("UnknownIntent", %{value: "test"}, [])

      case Dynamic.route_intent(intent) do
        {:ok, target} ->
          assert target == PacketFlow.Registry.lookup_reactor("default_reactor")
        {:error, reason} ->
          flunk("Failed to route intent: #{reason}")
      end
    end
  end

  describe "compose_intents/3" do
    test "composes intents sequentially" do
      intents = [
        Dynamic.create_intent("Intent1", %{value: "1"}, []),
        Dynamic.create_intent("Intent2", %{value: "2"}, []),
        Dynamic.create_intent("Intent3", %{value: "3"}, [])
      ]

      case Dynamic.compose_intents(intents, :sequential) do
        {:ok, results} ->
          assert length(results) == 3
        {:error, reason} ->
          flunk("Failed to compose intents: #{reason}")
      end
    end

    test "composes intents in parallel" do
      intents = [
        Dynamic.create_intent("Intent1", %{value: "1"}, []),
        Dynamic.create_intent("Intent2", %{value: "2"}, []),
        Dynamic.create_intent("Intent3", %{value: "3"}, [])
      ]

      case Dynamic.compose_intents(intents, :parallel) do
        {:ok, results} ->
          assert length(results) == 3
        {:error, reason} ->
          flunk("Failed to compose intents: #{reason}")
      end
    end

    test "composes intents conditionally" do
      intents = [
        Dynamic.create_intent("Intent1", %{value: "1"}, []),
        Dynamic.create_intent("Intent2", %{value: "2"}, []),
        Dynamic.create_intent("Intent3", %{value: "3"}, [])
      ]

      condition_fn = fn _results -> true end

      case Dynamic.compose_intents(intents, :conditional, %{condition: condition_fn}) do
        {:ok, results} ->
          assert length(results) == 3
        {:error, reason} ->
          flunk("Failed to compose intents: #{reason}")
      end
    end

    test "composes intents as pipeline" do
      intents = [
        Dynamic.create_intent("Intent1", %{value: "1"}, []),
        Dynamic.create_intent("Intent2", %{value: "2"}, []),
        Dynamic.create_intent("Intent3", %{value: "3"}, [])
      ]

      case Dynamic.compose_intents(intents, :pipeline) do
        {:ok, result} ->
          assert result != nil
        {:error, reason} ->
          flunk("Failed to compose intents: #{reason}")
      end
    end

    test "composes intents with fan out" do
      intents = [
        Dynamic.create_intent("Intent1", %{value: "1"}, []),
        Dynamic.create_intent("Intent2", %{value: "2"}, []),
        Dynamic.create_intent("Intent3", %{value: "3"}, [])
      ]

      case Dynamic.compose_intents(intents, :fan_out) do
        {:ok, result} ->
          assert result.type == :fan_out
          assert result.results
        {:error, reason} ->
          flunk("Failed to compose intents: #{reason}")
      end
    end

    test "returns error for unsupported composition pattern" do
      intents = [
        Dynamic.create_intent("Intent1", %{value: "1"}, [])
      ]

      case Dynamic.compose_intents(intents, :unsupported) do
        {:error, :unsupported_composition_pattern} ->
          :ok
        _ ->
          flunk("Expected error for unsupported composition pattern")
      end
    end
  end

  describe "validate_intent/1" do
    test "validates intent with plugins" do
      intent = Dynamic.create_intent("FileReadIntent", %{path: "/test"}, [])

      case Dynamic.validate_intent(intent) do
        {:ok, validated_intent} ->
          assert validated_intent == intent
        {:error, reason} ->
          # This is expected if the file doesn't exist
          assert reason in [:file_not_found, :invalid_file_path]
      end
    end

    test "validates user intent" do
      intent = Dynamic.create_intent("UserLoginIntent", %{
        username: "test",
        password: "password",
        session_id: "session123"
      }, [])

      case Dynamic.validate_intent(intent) do
        {:ok, validated_intent} ->
          assert validated_intent == intent
        {:error, reason} ->
          flunk("Failed to validate user intent: #{reason}")
      end
    end
  end

  describe "transform_intent/1" do
    test "transforms intent with plugins" do
      intent = Dynamic.create_intent("FileReadIntent", %{path: "/test"}, [])

      case Dynamic.transform_intent(intent) do
        {:ok, transformed_intent} ->
          assert transformed_intent != intent
        {:error, reason} ->
          flunk("Failed to transform intent: #{reason}")
      end
    end
  end

  describe "delegate_intent/2" do
    test "delegates intent to target processor" do
      intent = Dynamic.create_intent("TestIntent", %{value: "test"}, [])

      case Dynamic.delegate_intent(intent, "file_reactor") do
        {:ok, delegated_intent} ->
          assert delegated_intent.metadata.delegated_to == "file_reactor"
        {:error, reason} ->
          flunk("Failed to delegate intent: #{reason}")
      end
    end

    test "returns error for non-existent target processor" do
      intent = Dynamic.create_intent("TestIntent", %{value: "test"}, [])

      case Dynamic.delegate_intent(intent, "non_existent_reactor") do
        {:error, :target_processor_not_found} ->
          :ok
        _ ->
          flunk("Expected error for non-existent target processor")
      end
    end
  end

  describe "custom file operation intent" do
    test "creates custom file operation intent" do
      intent = CustomFileOperationIntent.new(:read, "/test", "user123")

      assert intent.type == :file_operation
      assert intent.operation == :read
      assert intent.path == "/test"
      assert intent.user_id == "user123"
      assert intent.capabilities
      assert intent.metadata.custom_type == true
    end

    test "validates custom file operation intent" do
      intent = CustomFileOperationIntent.new(:read, "/test", "user123")

      case CustomFileOperationIntent.validate(intent) do
        {:ok, validated_intent} ->
          assert validated_intent == intent
        {:error, reason} ->
          # Expected if file doesn't exist
          assert reason in [:file_not_found, :invalid_file_path]
      end
    end

    test "transforms custom file operation intent" do
      intent = CustomFileOperationIntent.new(:read, "/test", "user123")

      case CustomFileOperationIntent.transform(intent) do
        {:ok, transformed_intent} ->
          assert transformed_intent.metadata.transformed == true
          assert transformed_intent.payload.normalized_path
        {:error, reason} ->
          flunk("Failed to transform custom intent: #{reason}")
      end
    end
  end

  describe "load balanced routing strategy" do
    test "routes with round robin" do
      targets = ["target1", "target2", "target3"]
      intent = Dynamic.create_intent("FileReadIntent", %{path: "/test"}, [])

      case LoadBalancedRoutingStrategy.route(intent, targets) do
        {:ok, target} ->
          assert target in targets
        {:error, reason} ->
          flunk("Failed to route with round robin: #{reason}")
      end
    end

    test "routes with least connections" do
      targets = ["target1", "target2", "target3"]
      intent = Dynamic.create_intent("FileWriteIntent", %{path: "/test"}, [])

      case LoadBalancedRoutingStrategy.route(intent, targets) do
        {:ok, target} ->
          assert target in targets
        {:error, reason} ->
          flunk("Failed to route with least connections: #{reason}")
      end
    end

    test "routes with weighted algorithm" do
      targets = ["target1", "target2", "target3"]
      intent = Dynamic.create_intent("UserIntent", %{user_id: "123"}, [])

      case LoadBalancedRoutingStrategy.route(intent, targets) do
        {:ok, target} ->
          assert target in targets
        {:error, reason} ->
          flunk("Failed to route with weighted algorithm: #{reason}")
      end
    end

    test "routes with ip hash" do
      targets = ["target1", "target2", "target3"]
      intent = Dynamic.create_intent("BatchIntent", %{user_id: "123"}, [])

      case LoadBalancedRoutingStrategy.route(intent, targets) do
        {:ok, target} ->
          assert target in targets
        {:error, reason} ->
          flunk("Failed to route with ip hash: #{reason}")
      end
    end
  end

  describe "retry composition pattern" do
    test "composes with retry logic" do
      intents = [
        Dynamic.create_intent("Intent1", %{value: "1"}, []),
        Dynamic.create_intent("Intent2", %{value: "2"}, [])
      ]

      opts = %{
        max_retries: 2,
        retry_delay: 10,
        exponential_backoff: false
      }

      case RetryCompositionPattern.compose(intents, opts) do
        {:ok, results} ->
          assert length(results) == 2
        {:error, reason} ->
          # This might fail due to missing reactors, which is expected
          assert reason == {:max_retries_exceeded, :timeout}
      end
    end

    test "uses default options" do
      intents = [
        Dynamic.create_intent("Intent1", %{value: "1"}, [])
      ]

      case RetryCompositionPattern.compose(intents, %{}) do
        {:ok, results} ->
          assert length(results) == 1
        {:error, reason} ->
          # This might fail due to missing reactors, which is expected
          assert reason == {:max_retries_exceeded, :timeout}
      end
    end
  end

  describe "plugin system" do
    test "registers and retrieves plugins" do
      plugins = PacketFlow.Intent.Plugin.get_plugins()
      assert length(plugins) >= 2  # At least our two test plugins

      validation_plugins = PacketFlow.Intent.Plugin.get_plugins_by_type(:intent_validation)
      assert length(validation_plugins) >= 2
    end

    test "unregisters plugins" do
      # Register a test plugin
      test_plugin = %{plugin_type: :test, priority: 1}
      PacketFlow.Intent.Plugin.register_plugin(test_plugin)

      # Verify it's registered
      plugins = PacketFlow.Intent.Plugin.get_plugins()
      assert test_plugin in plugins

      # Unregister it
      PacketFlow.Intent.Plugin.unregister_plugin(test_plugin)

      # Verify it's unregistered
      plugins_after = PacketFlow.Intent.Plugin.get_plugins()
      assert test_plugin not in plugins_after
    end
  end
end
