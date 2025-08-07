defmodule PacketFlow.DSLSimpleTest do
  use ExUnit.Case, async: false
  use PacketFlow.DSL

  test "DSL macros work correctly" do
    # Test 1: Simple capability
    defcapability TestCap2_Simple do
      def read(path), do: {:read, path}
      def write(path), do: {:write, path}
    end

    assert TestCap2_Simple.read("/test.txt") == {:read, "/test.txt"}
    assert TestCap2_Simple.write("/test.txt") == {:write, "/test.txt"}
    assert TestCap2_Simple.implies?({:read, "/test.txt"}, {:read, "/test.txt"})
    assert TestCap2_Simple.compose([{:read, "/test.txt"}]) == MapSet.new([{:read, "/test.txt"}])
    assert TestCap2_Simple.grants({:read, "/test.txt"}) == []

    # Test 2: Simple context
    defcontext TestContext2_Simple_Unique do
      defstruct [:field1]

      def new(attrs \\ []) do
        struct(__MODULE__, attrs)
      end
    end

    context = TestContext2_Simple_Unique.new(field1: "value1")
    assert context.field1 == "value1"
    assert TestContext2_Simple_Unique.propagate(context, SomeModule) == context
    assert TestContext2_Simple_Unique.compose(context, context, :merge) == context

    # Test 3: Simple intent
    defintent TestIntent2_Simple do
      defstruct [:field1, :field2]
    end

    intent = struct(TestIntent2_Simple, field1: "value1", field2: "value2")
    assert TestIntent2_Simple.required_capabilities(intent) == []
    assert %PacketFlow.Reactor.Message{} = TestIntent2_Simple.to_reactor_message(intent)
    assert %PacketFlow.Effect{} = TestIntent2_Simple.to_effect(intent)

    # Test 4: Simple reactor
    defreactor TestReactor2_Simple do
      @initial_state %{count: 0}
    end

    assert {:ok, _pid} = TestReactor2_Simple.start_link()
    assert {:error, :not_implemented} = TestReactor2_Simple.process_intent(%{}, %{count: 0})

    # Test 5: Simple capability with implications
    defsimple_capability UserCap2_Simple, [:basic, :admin] do
      @implications [
        {{:admin}, [{:basic}]}
      ]
    end

    basic_cap = UserCap2_Simple.basic()
    admin_cap = UserCap2_Simple.admin()

    assert basic_cap == {:basic}
    assert admin_cap == {:admin}
    assert UserCap2_Simple.implies?(admin_cap, basic_cap)

    # Test 6: Simple context with fields
    defsimple_context UserContext2_Simple, [:user_id, :session_id, :capabilities] do
      @propagation_strategy :inherit
    end

    user_context = UserContext2_Simple.new(user_id: "user1", session_id: "session1")
    assert user_context.user_id == "user1"
    assert user_context.session_id == "session1"

    # Test 7: Simple intent with fields
    defsimple_intent SimpleIntent2_Simple, [:field1, :field2] do
      @capabilities []
      @effect nil
    end

    simple_intent = SimpleIntent2_Simple.new("value1", "value2")
    assert simple_intent.field1 == "value1"
    assert simple_intent.field2 == "value2"
    assert SimpleIntent2_Simple.required_capabilities(simple_intent) == []

    # Test 8: Simple reactor with state management
    defintent IncrementIntent2_Simple do
      defstruct []
    end

    defintent DecrementIntent2_Simple do
      defstruct []
    end

    defsimple_reactor CounterReactor2_Simple, [:count] do
      def process_intent(intent, state) do
        case intent do
          %IncrementIntent2_Simple{} ->
            new_state = %{state | count: state.count + 1}
            {:ok, new_state, []}
          %DecrementIntent2_Simple{} ->
            new_state = %{state | count: state.count - 1}
            {:ok, new_state, []}
          _ ->
            {:error, :unsupported_intent}
        end
      end
    end

    initial_state = struct(CounterReactor2_Simple, count: 0)

    assert {:ok, new_state, []} = CounterReactor2_Simple.process_intent(struct(IncrementIntent2_Simple), initial_state)
    assert new_state.count == 1
    assert {:ok, final_state, []} = CounterReactor2_Simple.process_intent(struct(DecrementIntent2_Simple), new_state)
    assert final_state.count == 0

    # Test 9: Complete workflow
    defsimple_capability FileCap2_Simple, [:read, :write, :admin] do
      @implications [
        {{:admin}, [{:read, :any}, {:write, :any}]},
        {{:write, :any}, [{:read, :any}]}
      ]
    end

    defsimple_context FileContext2_Simple, [:user_id, :capabilities] do
      @propagation_strategy :inherit
    end

    defsimple_intent FileReadIntent2_Simple, [:path, :user_id] do
      @capabilities []
      @effect nil
    end

    defsimple_reactor FileReactor2_Simple, [:files] do
      def process_intent(intent, state) do
        case intent do
          %FileReadIntent2_Simple{} ->
            case Map.get(state.files, intent.path) do
              nil ->
                {:error, :file_not_found}
              content ->
                new_files = Map.put(state.files, intent.path, content)
                new_state = %{state | files: new_files}
                {:ok, new_state, []}
            end
          _ ->
            {:error, :unsupported_intent}
        end
      end
    end

    # Test the complete workflow
    context = FileContext2_Simple.new(user_id: "user1", capabilities: MapSet.new([{:read, :any}]))
    intent = FileReadIntent2_Simple.new("/test.txt", "user1")
    reactor_state = struct(FileReactor2_Simple, files: %{"/test.txt" => "Hello, World!"})

    assert FileReadIntent2_Simple.required_capabilities(intent) == []
    assert %PacketFlow.Reactor.Message{} = FileReadIntent2_Simple.to_reactor_message(intent, context: context)
    assert {:ok, _new_state, []} = FileReactor2_Simple.process_intent(intent, reactor_state)
  end
end
