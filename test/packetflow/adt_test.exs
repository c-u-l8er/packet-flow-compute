defmodule PacketFlow.ADTTest do
  use ExUnit.Case, async: true
  use PacketFlow.ADT
  use PacketFlow.DSL

  # Test capability definition
  defmodule TestCap do
    @behaviour PacketFlow.Capability

    def read(path), do: {:read, path}
    def write(path), do: {:write, path}
    def delete(path), do: {:delete, path}
    def admin(), do: {:admin}

    def implies?(cap1, cap2) do
      case {cap1, cap2} do
        {{:admin}, {:read, _}} -> true
        {{:admin}, {:write, _}} -> true
        {{:admin}, {:delete, _}} -> true
        {{:delete, _}, {:read, _}} -> true
        {{:delete, _}, {:write, _}} -> true
        {same, same} -> true
        _ -> false
      end
    end

    def compose(caps) when is_list(caps) do
      caps
      |> Enum.reduce(MapSet.new(), fn cap, acc ->
        granted = grants(cap)
        MapSet.union(acc, MapSet.new([cap | granted]))
      end)
    end

    def grants(capability) do
      case capability do
        {:admin} -> [TestCap.read(:any), TestCap.write(:any), TestCap.delete(:any)]
        {:delete, _} -> [TestCap.read(:any), TestCap.write(:any)]
        _ -> []
      end
    end
  end

  # Test context definition
  defmodule TestContext do
    @behaviour PacketFlow.Context

    defstruct [:user_id, :session_id, :request_id, :capabilities]

    @type t :: %__MODULE__{
      user_id: String.t(),
      session_id: String.t(),
      request_id: String.t(),
      capabilities: MapSet.t()
    }

    def new(attrs \\ []) do
      struct(__MODULE__, attrs)
      |> compute_capabilities()
      |> ensure_request_id()
    end

    def propagate(context, _target_module) do
      %__MODULE__{
        user_id: context.user_id,
        session_id: context.session_id,
        request_id: generate_request_id(),
        capabilities: context.capabilities
      }
    end

    def compose(context1, context2, _strategy) do
      %__MODULE__{
        user_id: context2.user_id,
        session_id: context2.session_id,
        request_id: generate_request_id(),
        capabilities: MapSet.union(context1.capabilities, context2.capabilities)
      }
    end

    defp compute_capabilities(context) do
      capabilities = case context.user_id do
        "admin" -> MapSet.new([TestCap.admin()])
        "user" -> MapSet.new([TestCap.read(:any), TestCap.write(:any)])
        _ -> MapSet.new([TestCap.read(:any)])
      end
      %{context | capabilities: capabilities}
    end

    defp generate_request_id, do: "req_#{:rand.uniform(1000)}"

    defp ensure_request_id(context) do
      if context.request_id == nil do
        %{context | request_id: generate_request_id()}
      else
        context
      end
    end
  end

  # Test intent definition
  defmodule TestIntent do
    @behaviour PacketFlow.Intent

    def read_file(path, context), do: {:read_file, path, context}
    def write_file(path, content, context), do: {:write_file, path, content, context}
    def delete_file(path, context), do: {:delete_file, path, context}

    def required_capabilities(intent \\ nil) do
      case intent do
        {:read_file, _, _} -> [TestCap.read(:any)]
        {:write_file, _, _, _} -> [TestCap.write(:any)]
        {:delete_file, _, _} -> [TestCap.delete(:any)]
        _ -> [TestCap.read(:any)]
      end
    end

    def to_reactor_message(intent, opts \\ []) do
      %PacketFlow.Reactor.Message{
        intent: intent,
        capabilities: required_capabilities(intent),
        context: extract_context(intent),
        metadata: Keyword.get(opts, :metadata, %{}),
        timestamp: System.monotonic_time(:microsecond)
      }
    end

    def to_effect(intent, opts \\ []) do
      PacketFlow.Effect.new(
        intent: intent,
        capabilities: required_capabilities(intent),
        context: extract_context(intent),
        continuation: Keyword.get(opts, :continuation)
      )
    end

    defp extract_context({_, _, context}), do: context
    defp extract_context({_, _, _, context}), do: context
    defp extract_context(_), do: TestContext.new()
  end

  # Test reactor definition
  defmodule TestReactor do
    @behaviour PacketFlow.Reactor
    use GenServer

    def start_link(opts \\ []) do
      GenServer.start_link(__MODULE__, opts, name: __MODULE__)
    end

    def init(opts) do
      {:ok, %{
        capabilities: Keyword.get(opts, :capabilities, MapSet.new()),
        state: Keyword.get(opts, :initial_state, %{})
      }}
    end

    def handle_call({:process_intent, intent}, _from, state) do
      case check_capabilities(intent, state.capabilities) do
        :ok ->
          case process_intent(intent, state) do
            {:ok, new_state, effects} ->
              schedule_effects(effects)
              {:reply, :ok, new_state}
            {:error, reason} ->
              {:reply, {:error, reason}, state}
          end
        {:error, missing_caps} ->
          {:reply, {:error, {:insufficient_capabilities, missing_caps}}, state}
      end
    end

    def process_intent(intent, state) do
      case intent do
        {:read_file, path, context} ->
          content = "Content of #{path}"
          {:ok, state, [{:file_read, path, content, context}]}

        {:write_file, path, content, context} ->
          {:ok, state, [{:file_written, path, byte_size(content), context}]}

        {:delete_file, path, context} ->
          {:ok, state, [{:file_deleted, path, context}]}

        _ ->
          {:error, {:unhandled_intent, intent}}
      end
    end

    defp check_capabilities(intent, available_caps) do
      required = TestIntent.required_capabilities(intent)
      missing = Enum.reject(required, fn cap ->
        Enum.any?(available_caps, fn available ->
          TestCap.implies?(available, cap)
        end)
      end)

      case missing do
        [] -> :ok
        _ -> {:error, missing}
      end
    end

    defp schedule_effects(effects) do
      Enum.each(effects, fn effect ->
        spawn(fn -> execute_effect(effect) end)
      end)
    end

    defp execute_effect(effect) do
      IO.puts("Executing effect: #{inspect(effect)}")
      PacketFlow.Effect.execute(effect)
    end
  end

  describe "Intent DSL" do
    test "creates valid intents" do
      context = TestContext.new(user_id: "user123", session_id: "session456")

      read_intent = TestIntent.read_file("/path/to/file", context)
      write_intent = TestIntent.write_file("/path/to/file", "content", context)
      delete_intent = TestIntent.delete_file("/path/to/file", context)

      assert is_tuple(read_intent)
      assert is_tuple(write_intent)
      assert is_tuple(delete_intent)
    end

    test "provides capability checking" do
      context = TestContext.new(user_id: "user123")

      read_intent = TestIntent.read_file("/path/to/file", context)
      write_intent = TestIntent.write_file("/path/to/file", "content", context)
      delete_intent = TestIntent.delete_file("/path/to/file", context)

      # Test intent-specific capabilities
      assert TestIntent.required_capabilities(read_intent) == [TestCap.read(:any)]
      assert TestIntent.required_capabilities(write_intent) == [TestCap.write(:any)]
      assert TestIntent.required_capabilities(delete_intent) == [TestCap.delete(:any)]
    end

    test "generates reactor messages" do
      context = TestContext.new(user_id: "user123")
      intent = TestIntent.read_file("/path/to/file", context)

      message = TestIntent.to_reactor_message(intent, metadata: %{priority: :high})

      assert %PacketFlow.Reactor.Message{} = message
      assert message.intent == intent
      assert message.context == context
      assert message.metadata == %{priority: :high}
      assert is_integer(message.timestamp)
    end

    test "generates effects" do
      context = TestContext.new(user_id: "user123")
      intent = TestIntent.read_file("/path/to/file", context)

      effect = TestIntent.to_effect(intent, continuation: fn -> :ok end)

      assert %PacketFlow.Effect{} = effect
      assert effect.intent == intent
      assert effect.context == context
      assert is_function(effect.continuation)
      assert effect.status == :pending
    end
  end

  describe "Context DSL" do
    test "creates context struct" do
      context = TestContext.new(user_id: "user123", session_id: "session456")

      assert %TestContext{} = context
      assert context.user_id == "user123"
      assert context.session_id == "session456"
      assert is_binary(context.request_id)
      assert %MapSet{} = context.capabilities
    end

    test "computes capabilities" do
      admin_context = TestContext.new(user_id: "admin")
      user_context = TestContext.new(user_id: "user")
      guest_context = TestContext.new(user_id: "guest")

      # Admin should have admin capability
      assert MapSet.member?(admin_context.capabilities, TestCap.admin())

      # User should have read and write capabilities
      assert MapSet.member?(user_context.capabilities, TestCap.read(:any))
      assert MapSet.member?(user_context.capabilities, TestCap.write(:any))

      # Guest should only have read capability
      assert MapSet.member?(guest_context.capabilities, TestCap.read(:any))
      refute MapSet.member?(guest_context.capabilities, TestCap.write(:any))
    end

    test "supports propagation" do
      source_context = TestContext.new(
        user_id: "user123",
        session_id: "session456",
        request_id: "req789"
      )

      target_context = TestContext.propagate(source_context, TestContext)

      assert target_context.user_id == "user123"
      assert target_context.session_id == "session456"
      # request_id should be regenerated, not propagated
      assert target_context.request_id != "req789"
    end

    test "supports composition" do
      context1 = TestContext.new(user_id: "user1", session_id: "session1")
      context2 = TestContext.new(user_id: "user2", session_id: "session2")

      merged = TestContext.compose(context1, context2, :merge)

      # Should use values from context2 (right bias in merge)
      assert merged.user_id == "user2"
      assert merged.session_id == "session2"
    end
  end

  describe "Capability DSL" do
    test "creates valid capabilities" do
      read_cap = TestCap.read("/test/file")
      write_cap = TestCap.write("/test/file")
      delete_cap = TestCap.delete("/test/file")
      admin_cap = TestCap.admin()

      assert is_tuple(read_cap)
      assert is_tuple(write_cap)
      assert is_tuple(delete_cap)
      assert is_tuple(admin_cap)
    end

    test "provides implication checking" do
      read_cap = TestCap.read("/test/file")
      write_cap = TestCap.write("/test/file")
      delete_cap = TestCap.delete("/test/file")
      admin_cap = TestCap.admin()

      # Admin grants all capabilities
      assert TestCap.implies?(admin_cap, read_cap)
      assert TestCap.implies?(admin_cap, write_cap)
      assert TestCap.implies?(admin_cap, delete_cap)

      # Delete grants Read and Write
      assert TestCap.implies?(delete_cap, read_cap)
      assert TestCap.implies?(delete_cap, write_cap)

      # Read doesn't grant Write
      refute TestCap.implies?(read_cap, write_cap)
    end

    test "provides capability composition" do
      read_cap = TestCap.read("/test/file")
      write_cap = TestCap.write("/test/file")
      admin_cap = TestCap.admin()

      composed = TestCap.compose([read_cap, write_cap, admin_cap])

      assert %MapSet{} = composed
      assert MapSet.size(composed) >= 3
    end

    test "provides grant checking" do
      _read_cap = TestCap.read("/test/file")
      _write_cap = TestCap.write("/test/file")
      delete_cap = TestCap.delete("/test/file")
      admin_cap = TestCap.admin()

      # Admin grants Read, Write, and Delete
      grants = TestCap.grants(admin_cap)
      assert TestCap.read(:any) in grants
      assert TestCap.write(:any) in grants
      assert TestCap.delete(:any) in grants

      # Delete grants Read and Write
      grants = TestCap.grants(delete_cap)
      assert TestCap.read(:any) in grants
      assert TestCap.write(:any) in grants
    end
  end

  describe "Reactor DSL" do
    test "creates reactor module" do
      assert function_exported?(TestReactor, :start_link, 1)
    end

    test "starts reactor process" do
      {:ok, reactor} = TestReactor.start_link(initial_state: %{})
      assert is_pid(reactor)

      # Clean up
      GenServer.stop(reactor)
    end

    test "handles intents with capability checking" do
      {:ok, reactor} = TestReactor.start_link(
        initial_state: %{},
        capabilities: MapSet.new([TestCap.read(:any), TestCap.write(:any)])
      )

      context = TestContext.new(user_id: "user123")
      intent = TestIntent.read_file("/test/file", context)

      # This should work since we have the required capabilities
      result = GenServer.call(reactor, {:process_intent, intent})
      assert result == :ok

      # Clean up
      GenServer.stop(reactor)
    end

    test "rejects intents with insufficient capabilities" do
      {:ok, reactor} = TestReactor.start_link(
        initial_state: %{},
        capabilities: MapSet.new([TestCap.read(:any)]) # Missing Write capability
      )

      context = TestContext.new(user_id: "user123")
      intent = TestIntent.write_file("/test/file", "content", context)

      # This should fail since we don't have Write capability
      result = GenServer.call(reactor, {:process_intent, intent})
      assert {:error, {:insufficient_capabilities, _missing}} = result

      # Clean up
      GenServer.stop(reactor)
    end
  end

  describe "Effect system" do
    test "creates effects" do
      context = TestContext.new(user_id: "user123")
      intent = TestIntent.read_file("/test/file", context)

      effect = PacketFlow.Effect.new(
        intent: intent,
        capabilities: [TestCap.read(:any)],
        context: context,
        continuation: fn -> :ok end
      )

      assert %PacketFlow.Effect{} = effect
      assert effect.intent == intent
      assert effect.capabilities == [TestCap.read(:any)]
      assert effect.context == context
      assert is_function(effect.continuation)
      assert effect.status == :pending
    end

    test "executes effects" do
      effect = PacketFlow.Effect.new(
        intent: :test_intent,
        capabilities: [],
        context: %{},
        continuation: fn -> :test_result end
      )

      result = PacketFlow.Effect.execute(effect)
      assert result == effect
    end
  end

  describe "Registry integration" do
    test "registers and looks up components" do
      # Register a reactor
      reactor_info = %{id: "test_reactor", name: "TestReactor"}
      :ok = PacketFlow.Registry.register_reactor("test_reactor", reactor_info)

      # Look it up
      assert ^reactor_info = PacketFlow.Registry.lookup_reactor("test_reactor")

      # List reactors
      reactors = PacketFlow.Registry.list_reactors()
      assert "test_reactor" in reactors
    end

    test "handles missing components" do
      assert nil == PacketFlow.Registry.lookup_reactor("nonexistent")
      assert nil == PacketFlow.Registry.lookup_capability("nonexistent")
      assert nil == PacketFlow.Registry.lookup_context("nonexistent")
      assert nil == PacketFlow.Registry.lookup_intent("nonexistent")
    end
  end

  describe "Error handling" do
    test "handles malformed intents" do
      # Test with invalid intent structure
      assert {:error, {:unhandled_intent, :invalid_intent}} =
        TestReactor.process_intent(:invalid_intent, %{})
    end
  end

  describe "Integration tests" do
    test "full workflow with intent, context, and reactor" do
      # Create context
      context = TestContext.new(user_id: "user123", session_id: "session456")

      # Create intent
      intent = TestIntent.read_file("/test/file", context)

      # Create reactor
      {:ok, reactor} = TestReactor.start_link(
        initial_state: %{},
        capabilities: MapSet.new([TestCap.read(:any), TestCap.write(:any)])
      )

      # Process intent
      result = GenServer.call(reactor, {:process_intent, intent})
      assert result == :ok

      # Clean up
      GenServer.stop(reactor)
    end

    test "capability-based security" do
      # Create context with different user
      context = TestContext.new(user_id: "user456", session_id: "session789")

      # Create intent requiring specific capability
      intent = TestIntent.delete_file("/sensitive/file", context)

      # Create reactor with limited capabilities
      {:ok, reactor} = TestReactor.start_link(
        initial_state: %{},
        capabilities: MapSet.new([TestCap.read(:any)]) # No delete capability
      )

      # Should be rejected
      result = GenServer.call(reactor, {:process_intent, intent})
      assert {:error, {:insufficient_capabilities, _missing}} = result

      # Clean up
      GenServer.stop(reactor)
    end
  end
end
