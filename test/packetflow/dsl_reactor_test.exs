defmodule PacketFlow.DSLReactorTest do
  use ExUnit.Case, async: false
  use PacketFlow.DSL

  test "defreactor creates reactor with default implementations" do
    defreactor TestReactor1_Default do
      @initial_state %{count: 0}
    end

    assert {:ok, _pid} = TestReactor1_Default.start_link()
    assert {:error, :not_implemented} = TestReactor1_Default.process_intent(%{}, %{count: 0})
  end

  test "defreactor with custom state management" do
    # Define test intents first
    defintent IncrementIntent1_Custom do
      defstruct []
    end

    defintent DecrementIntent1_Custom do
      defstruct []
    end

    defreactor CounterReactor1_Custom do
      @initial_state %{count: 0}

      def process_intent(intent, state) do
        case intent do
          %IncrementIntent1_Custom{} ->
            new_state = update_in(state, [:count], &(&1 + 1))
            {:ok, new_state, []}
          %DecrementIntent1_Custom{} ->
            new_state = update_in(state, [:count], &(&1 - 1))
            {:ok, new_state, []}
          _ ->
            {:error, :unsupported_intent}
        end
      end
    end

    assert {:ok, %{count: 1}, []} = CounterReactor1_Custom.process_intent(struct(IncrementIntent1_Custom), %{count: 0})
    assert {:ok, %{count: 0}, []} = CounterReactor1_Custom.process_intent(struct(DecrementIntent1_Custom), %{count: 1})
    assert {:error, :unsupported_intent} = CounterReactor1_Custom.process_intent(%{}, %{count: 0})
  end

    test "defsimple_reactor creates reactor with basic state management" do
    # Define test intents first
    defintent SimpleIncrementIntent1_Basic do
      defstruct []
    end

    defintent SimpleDecrementIntent1_Basic do
      defstruct []
    end

    defsimple_reactor SimpleReactor1_Basic, [:count] do
      def process_intent(intent, state) do
        case intent do
          %SimpleIncrementIntent1_Basic{} ->
            new_state = %{state | count: state.count + 1}
            {:ok, new_state, []}
          %SimpleDecrementIntent1_Basic{} ->
            new_state = %{state | count: state.count - 1}
            {:ok, new_state, []}
          _ ->
            {:error, :unsupported_intent}
        end
      end
    end

    initial_state = struct(SimpleReactor1_Basic, count: 0)

    assert {:ok, new_state, []} = SimpleReactor1_Basic.process_intent(struct(SimpleIncrementIntent1_Basic), initial_state)
    assert new_state.count == 1
    assert {:ok, final_state, []} = SimpleReactor1_Basic.process_intent(struct(SimpleDecrementIntent1_Basic), new_state)
    assert final_state.count == 0
  end
end
