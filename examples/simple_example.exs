#!/usr/bin/env elixir

# Simple Example using PacketFlow DSL Simple Macros
# This example demonstrates how to use the simple DSL macros for quick prototyping.

defmodule SimpleExample do
  use PacketFlow.DSL

  # Define simple capabilities
  defsimple_capability UserCap, [:basic, :admin] do
    @implications [
      {UserCap.admin, [UserCap.basic]}
    ]
  end

  # Define simple context
  defsimple_context UserContext, [:user_id, :capabilities] do
    @propagation_strategy :inherit
  end

  # Define simple intents
  defsimple_intent IncrementIntent, [:user_id] do
    @capabilities [UserCap.basic]
    @effect CounterEffect.increment
  end

  defsimple_intent DecrementIntent, [:user_id] do
    @capabilities [UserCap.basic]
    @effect CounterEffect.decrement
  end

  defsimple_intent ResetIntent, [:user_id] do
    @capabilities [UserCap.admin]
    @effect CounterEffect.reset
  end

  # Define simple reactor
  defsimple_reactor CounterReactor, [:count] do
    def process_intent(intent, state) do
      case intent do
        %IncrementIntent{} ->
          new_state = %{state | count: state.count + 1}
          {:ok, new_state, []}
        %DecrementIntent{} ->
          new_state = %{state | count: state.count - 1}
          {:ok, new_state, []}
        %ResetIntent{} ->
          new_state = %{state | count: 0}
          {:ok, new_state, []}
        _ ->
          {:error, :unsupported_intent}
      end
    end
  end

  # Define effects
  defmodule CounterEffect do
    def increment(intent) do
      IO.puts("Incrementing counter for user: #{intent.user_id}")
      {:ok, :incremented}
    end

    def decrement(intent) do
      IO.puts("Decrementing counter for user: #{intent.user_id}")
      {:ok, :decremented}
    end

    def reset(intent) do
      IO.puts("Resetting counter for user: #{intent.user_id}")
      {:ok, :reset}
    end
  end

  # Example usage
  def run_example do
    IO.puts("=== Simple Counter Example ===")

    # Create contexts for different users
    admin_context = UserContext.new(user_id: "admin", capabilities: MapSet.new([UserCap.admin]))
    user_context = UserContext.new(user_id: "user", capabilities: MapSet.new([UserCap.basic]))

    IO.puts("Admin capabilities: #{inspect(admin_context.capabilities)}")
    IO.puts("User capabilities: #{inspect(user_context.capabilities)}")

    # Test capability implications
    admin_cap = UserCap.admin()
    basic_cap = UserCap.basic()

    IO.puts("\n=== Capability Tests ===")
    IO.puts("Admin implies basic: #{UserCap.implies?(admin_cap, basic_cap)}")
    IO.puts("Basic implies admin: #{UserCap.implies?(basic_cap, admin_cap)}")

    # Create intents
    increment_intent = IncrementIntent.new("user")
    decrement_intent = DecrementIntent.new("user")
    reset_intent = ResetIntent.new("admin")

    # Test intent capabilities
    IO.puts("\n=== Intent Capability Tests ===")
    IO.puts("Increment intent capabilities: #{inspect(IncrementIntent.required_capabilities(increment_intent))}")
    IO.puts("Reset intent capabilities: #{inspect(ResetIntent.required_capabilities(reset_intent))}")

    # Test reactor operations
    IO.puts("\n=== Reactor Operations ===")
    
    initial_state = %CounterReactor{count: 0}
    
    # Increment
    {:ok, new_state, []} = CounterReactor.process_intent(increment_intent, initial_state)
    IO.puts("After increment: #{new_state.count}")
    
    # Increment again
    {:ok, new_state, []} = CounterReactor.process_intent(increment_intent, new_state)
    IO.puts("After second increment: #{new_state.count}")
    
    # Decrement
    {:ok, new_state, []} = CounterReactor.process_intent(decrement_intent, new_state)
    IO.puts("After decrement: #{new_state.count}")
    
    # Reset (admin only)
    {:ok, new_state, []} = CounterReactor.process_intent(reset_intent, new_state)
    IO.puts("After reset: #{new_state.count}")

    # Test error cases
    invalid_intent = %{invalid: "intent"}
    {:error, reason} = CounterReactor.process_intent(invalid_intent, new_state)
    IO.puts("Expected error (unsupported intent): #{reason}")

    IO.puts("\n=== Example completed successfully ===")
  end
end

# Run the example if this file is executed directly
if __ENV__.file == __FILE__ do
  SimpleExample.run_example()
end 