#!/usr/bin/env elixir

# Test script for the new PacketFlow Actor System (Phase 1)
# Run with: mix run test_actor_system.exs

defmodule ActorSystemTest do
  @moduledoc """
  Test script to validate the Phase 1 actor system implementation.
  """

  def run do
    IO.puts("🚀 Testing PacketFlow Actor System - Phase 1")
    IO.puts("=" <> String.duplicate("=", 50))

    # Start the application manually for testing
    start_application()

    # Run tests
    test_actor_creation()
    test_stateful_conversation()
    test_actor_state_persistence()
    test_actor_timeout_and_cleanup()

    IO.puts("\n✅ All actor system tests completed!")
  end

  defp start_application do
    IO.puts("\n📋 Using existing PacketFlow application...")

    # The application is already started by Mix, just register our test capability
    Process.sleep(100)  # Give the system time to be fully ready

    # Register our test capability
    case PacketFlow.CapabilityRegistry.register_module(PacketFlow.Capabilities.TestActorCapability) do
      {:ok, count} ->
        IO.puts("✅ Test actor capability registered (#{count} capabilities)")

      {:error, reason} ->
        IO.puts("❌ Failed to register test capability: #{inspect(reason)}")
        exit(:registration_failed)
    end
  end

  defp test_actor_creation do
    IO.puts("\n🧪 Test 1: Actor Creation and Basic Messaging")

    actor_id = "test_actor_#{:rand.uniform(1000)}"
    capability_id = :test_chat_actor

    # Send first message (should create actor)
    message1 = %{message: "Hello, I'm testing the actor system!", user_id: "test_user"}

    case PacketFlow.send_to_actor(capability_id, actor_id, message1) do
      {:ok, response1} ->
        IO.puts("✅ Actor created and responded: #{inspect(response1)}")

        # Verify actor exists
        case PacketFlow.get_actor_state(capability_id, actor_id) do
          {:ok, state} ->
            IO.puts("✅ Actor state retrieved: message_count = #{state.state.message_count}")

          {:error, reason} ->
            IO.puts("❌ Failed to get actor state: #{inspect(reason)}")
        end

      {:error, reason} ->
        IO.puts("❌ Failed to send message to actor: #{inspect(reason)}")
    end
  end

  defp test_stateful_conversation do
    IO.puts("\n🧪 Test 2: Stateful Conversation")

    actor_id = "conversation_actor_#{:rand.uniform(1000)}"
    capability_id = :test_chat_actor

    messages = [
      "Hi there!",
      "How are you doing?",
      "Tell me about yourself",
      "What do you remember about our conversation?"
    ]

    Enum.with_index(messages, 1)
    |> Enum.each(fn {msg, index} ->
      message = %{message: msg, user_id: "conversation_user"}

      case PacketFlow.send_to_actor(capability_id, actor_id, message) do
        {:ok, response} ->
          IO.puts("✅ Message #{index}: #{response.response}")
          IO.puts("   Conversation count: #{response.conversation_count}")

        {:error, reason} ->
          IO.puts("❌ Message #{index} failed: #{inspect(reason)}")
      end

      Process.sleep(50)  # Small delay between messages
    end)
  end

  defp test_actor_state_persistence do
    IO.puts("\n🧪 Test 3: Actor State Persistence")

    actor_id = "persistence_actor_#{:rand.uniform(1000)}"
    capability_id = :test_chat_actor

    # Send several messages
    1..5
    |> Enum.each(fn i ->
      message = %{message: "Persistence test message #{i}", user_id: "persistence_user"}
      PacketFlow.send_to_actor(capability_id, actor_id, message)
      Process.sleep(10)
    end)

    # Check final state
    case PacketFlow.get_actor_state(capability_id, actor_id) do
      {:ok, state} ->
        history_count = length(state.state.conversation_history)
        message_count = state.state.message_count

        IO.puts("✅ Actor persisted #{history_count} messages in history")
        IO.puts("✅ Message count: #{message_count}")

        if history_count == message_count and message_count == 5 do
          IO.puts("✅ State persistence working correctly")
        else
          IO.puts("❌ State persistence inconsistency detected")
        end

      {:error, reason} ->
        IO.puts("❌ Failed to check persistence: #{inspect(reason)}")
    end
  end

  defp test_actor_timeout_and_cleanup do
    IO.puts("\n🧪 Test 4: Actor Lifecycle Management")

    # List current actors
    case PacketFlow.list_actors() do
      {:ok, actors} ->
        actor_count = length(actors)
        IO.puts("✅ Currently #{actor_count} actors running")

        if actor_count > 0 do
          IO.puts("✅ Actors created successfully during tests")
        end

      {:error, reason} ->
        IO.puts("❌ Failed to list actors: #{inspect(reason)}")
    end

    # Test manual actor termination
    actor_id = "termination_test_#{:rand.uniform(1000)}"
    capability_id = :test_chat_actor

    # Create actor
    message = %{message: "About to be terminated", user_id: "termination_user"}
    PacketFlow.send_to_actor(capability_id, actor_id, message)

    # Terminate it
    case PacketFlow.terminate_actor(capability_id, actor_id, :test_termination) do
      :ok ->
        IO.puts("✅ Actor terminated successfully")

        # Verify it's gone
        case PacketFlow.get_actor_state(capability_id, actor_id) do
          {:error, :actor_not_found} ->
            IO.puts("✅ Actor properly cleaned up")

          {:ok, _} ->
            IO.puts("❌ Actor still exists after termination")
        end

      {:error, reason} ->
        IO.puts("❌ Failed to terminate actor: #{inspect(reason)}")
    end
  end
end

# Run the tests
ActorSystemTest.run()
