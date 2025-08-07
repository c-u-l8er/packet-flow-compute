defmodule PacketFlow.Capabilities.TestActorCapability do
  @moduledoc """
  Test actor capability to validate the actor system implementation.

  This demonstrates how to create a stateful capability that maintains
  conversation history and responds based on previous interactions.
  """

  use PacketFlow.ActorCapability
  require Logger

  actor_capability :test_chat_actor do
    intent "Test chat actor that maintains conversation history"
    requires [:message, :user_id]
    provides [:response, :conversation_count, :history_updated]

    initial_state %{
      conversation_history: [],
      message_count: 0,
      user_preferences: %{}
    }

    state_persistence :memory
    actor_timeout :timer.minutes(15)

    handle_message do
      # Pattern matching would be implemented here in full version
    end
  end

  # Override the default message handler for testing
  def handle_actor_message(message, context, current_state) do
    Logger.info("TestActorCapability handling message: #{inspect(message)}")

    # Extract message content
    message_content = Map.get(message, :message, "")
    user_id = Map.get(message, :user_id, "unknown")

    # Update conversation history
    new_history_entry = %{
      user_id: user_id,
      message: message_content,
      timestamp: DateTime.utc_now()
    }

    updated_history = [new_history_entry | current_state.conversation_history]
    updated_count = current_state.message_count + 1

    # Generate a simple response based on history
    response = generate_response(message_content, updated_history, updated_count)

    # Update state
    new_state = %{
      current_state |
      conversation_history: updated_history,
      message_count: updated_count
    }

    result = %{
      response: response,
      conversation_count: updated_count,
      history_updated: true,
      actor_id: context[:actor_id] || "unknown"
    }

    {:ok, result, new_state}
  end

  # Main capability function expected by the execution engine
  def test_chat_actor(payload, context) do
    Logger.info("TestActorCapability test_chat_actor called with payload: #{inspect(payload)}")

    # For now, just use stateless execution until actor system is fully integrated
    # TODO: Implement proper actor message routing when actor system is ready
    execute(payload, context)
  end

  # Fallback for non-actor execution
  def execute(payload, _context) do
    Logger.info("TestActorCapability executing in stateless mode: #{inspect(payload)}")

    response = %{
      response: "Stateless response to: #{Map.get(payload, :message, "")}",
      conversation_count: 1,
      history_updated: false
    }

    {:ok, response}
  end

  # Private helper functions

  defp generate_response(message, history, count) do
    cond do
      count == 1 ->
        "Hello! This is my first message. You said: '#{message}'"

      count <= 3 ->
        "Thanks for message ##{count}. You said: '#{message}'. We're just getting started!"

      count <= 10 ->
        prev_messages = Enum.take(history, 3) |> Enum.map(& &1.message) |> Enum.join(", ")
        "Message ##{count} received: '#{message}'. Recent context: #{prev_messages}"

      true ->
        "We've been chatting for a while (#{count} messages)! Latest: '#{message}'"
    end
  end
end
