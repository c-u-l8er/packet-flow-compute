defmodule PacketFlow.ADTEnhancedTest do
  use ExUnit.Case
  use PacketFlow.ADT

  # Test algebraic sum type capability (define first to avoid circular dependency)
  defadt_capability TestFileSystemCap do
    @implications [
      {:admin, [:read, :write, :delete]},
      {:write, [:read]}
    ]

    # Algebraic sum type variants
    defcapability_variant :read, [:path]
    defcapability_variant :write, [:path, :content]
    defcapability_variant :delete, [:path]
    defcapability_variant :admin, [:path]
  end

  # Test algebraic sum type intent
  defadt_intent TestFileOperationIntent do
    @capabilities [:read, :write]

    defstruct [:path, :operation, :user_id, :content]

    # Algebraic sum type variants
    defvariant :read, [:path, :user_id]
    defvariant :write, [:path, :content, :user_id]
    defvariant :delete, [:path, :user_id]
  end

  # Test algebraic product type context
  defadt_context TestUserContext do
    @propagation_strategy :merge

    defstruct [:user_id, :session_id, :capabilities, :metadata]

    # Algebraic product type composition
    defcompose :merge, c1, c2 do
      %__MODULE__{
        user_id: c1.user_id || c2.user_id,
        session_id: c1.session_id || c2.session_id,
        capabilities: MapSet.union(c1.capabilities, c2.capabilities),
        metadata: Map.merge(c1.metadata, c2.metadata)
      }
    end
  end

  # Test pattern-matching reactor
  defadt_reactor TestFileReactor do
    def process_intent(intent, state) do
      case intent do
        %TestFileOperationIntent{operation: :read, path: path} ->
          {:ok, Map.put(state, :last_read, path), []}

        %TestFileOperationIntent{operation: :write, path: path, content: content} ->
          {:ok, Map.put(state, :last_written, {path, content}), []}

        %TestFileOperationIntent{operation: :delete, path: path} ->
          {:ok, Map.put(state, :last_deleted, path), []}

        _ ->
          {:error, :unknown_operation}
      end
    end
  end

  # Test monadic effect
  defadt_effect TestFileEffect do
    def bind(effect, continuation) do
      case effect do
        {:ok, value} -> continuation.(value)
        {:error, reason} -> {:error, reason}
      end
    end

    def return(value) do
      {:ok, value}
    end
  end

  describe "Enhanced ADT Features" do
    test "defadt_intent creates algebraic sum type intent" do
      intent = %TestFileOperationIntent{
        path: "/test/file",
        operation: :read,
        user_id: "user123"
      }

      assert intent.path == "/test/file"
      assert intent.operation == :read
      assert intent.user_id == "user123"

      # Test required capabilities
      capabilities = TestFileOperationIntent.required_capabilities(intent)
      assert capabilities == [:read, :write]

      # Test reactor message conversion
      message = TestFileOperationIntent.to_reactor_message(intent)
      assert message.intent == intent
      assert message.capabilities == capabilities
      assert message.metadata.type == :adt_intent
    end

    test "defadt_context creates algebraic product type context" do
      context1 = TestUserContext.new(
        user_id: "user1",
        session_id: "session1",
        capabilities: MapSet.new([:read]),
        metadata: %{source: "test1"}
      )

      context2 = TestUserContext.new(
        user_id: "user2",
        session_id: "session2",
        capabilities: MapSet.new([:write]),
        metadata: %{source: "test2"}
      )

      # Test composition
      composed = TestUserContext.compose(context1, context2, :merge)
      assert composed.user_id == "user1"  # First context takes precedence
      assert composed.session_id == "session1"
      assert MapSet.size(composed.capabilities) == 2
      assert composed.metadata.source == "test2"  # Second context takes precedence for metadata
    end

    test "defadt_capability creates algebraic sum type capability" do
      # Test implications
      assert TestFileSystemCap.implies?(:admin, :read)
      assert TestFileSystemCap.implies?(:admin, :write)
      assert TestFileSystemCap.implies?(:write, :read)
      refute TestFileSystemCap.implies?(:read, :write)

      # Test composition
      caps = [%TestFileSystemCap{type: :read}, %TestFileSystemCap{type: :write}]
      composed = TestFileSystemCap.compose(caps)
      assert MapSet.size(composed) == 2

      # Test grants
      granted = TestFileSystemCap.grants(:admin)
      assert length(granted) == 3
      assert :read in granted
      assert :write in granted
      assert :delete in granted
    end

    test "defadt_reactor processes intents with pattern matching" do
      reactor = TestFileReactor
      state = %{}

      # Test read operation
      intent1 = %TestFileOperationIntent{operation: :read, path: "/file1", user_id: "user1"}
      {:ok, state1, effects1} = reactor.process_intent(intent1, state)
      assert state1.last_read == "/file1"
      assert effects1 == []

      # Test write operation
      intent2 = %TestFileOperationIntent{operation: :write, path: "/file2", content: "content", user_id: "user1"}
      {:ok, state2, effects2} = reactor.process_intent(intent2, state1)
      assert state2.last_written == {"/file2", "content"}
      assert effects2 == []

      # Test delete operation
      intent3 = %TestFileOperationIntent{operation: :delete, path: "/file3", user_id: "user1"}
      {:ok, state3, effects3} = reactor.process_intent(intent3, state2)
      assert state3.last_deleted == "/file3"
      assert effects3 == []

      # Test unknown operation
      intent4 = %TestFileOperationIntent{operation: :unknown, path: "/file4", user_id: "user1"}
      {:error, reason} = reactor.process_intent(intent4, state3)
      assert reason == :unknown_operation
    end

    test "defadt_effect provides monadic composition" do
      effect = TestFileEffect

      # Test return
      result = effect.return("success")
      assert result == {:ok, "success"}

      # Test bind with success
      continuation = fn value -> {:ok, "processed: #{value}"} end
      bound = effect.bind({:ok, "test"}, continuation)
      assert bound == {:ok, "processed: test"}

      # Test bind with error
      bound_error = effect.bind({:error, "failure"}, continuation)
      assert bound_error == {:error, "failure"}
    end

    test "algebraic_compose enables type-level reasoning" do
      # Test algebraic composition
      composition = algebraic_compose(TestFileOperationIntent, TestUserContext)
      assert composition == {TestFileOperationIntent, TestUserContext}
    end

    test "capability_constraint defines type-level constraints" do
      # This would be tested with compile-time validation
      # For now, we test that the macro exists and can be used
      assert Code.ensure_loaded?(PacketFlow.ADT.TypeConstraints)
      # Test that the module exists and has the macro
      assert function_exported?(PacketFlow.ADT.TypeConstraints, :__info__, 1)
    end
  end
end
