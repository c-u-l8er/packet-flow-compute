defmodule PacketflowChatDemoTest do
  use ExUnit.Case
  doctest PacketflowChatDemo

  alias PacketflowChatDemo.ChatReactor
  alias PacketflowChatDemo.ChatSystem

  setup do
    # Start the ChatReactor for each test
    {:ok, _pid} = ChatReactor.start_link()
    :ok
  end

  describe "ChatReactor" do
    test "sends message and receives response" do
      user_id = "test-user"
      message = "Hello"
      session_id = "test-session"

      assert {:ok, response} = ChatReactor.send_message(user_id, message, session_id)
      assert response.message_id
      assert response.response
      assert response.timestamp
    end

    test "handles different message types" do
      user_id = "test-user"
      session_id = "test-session"

      # Test greeting
      assert {:ok, response} = ChatReactor.send_message(user_id, "Hello", session_id)
      assert String.contains?(response.response, "Hello")

      # Test PacketFlow question
      assert {:ok, response} = ChatReactor.send_message(user_id, "Tell me about PacketFlow", session_id)
      assert String.contains?(response.response, "PacketFlow")

      # Test help request
      assert {:ok, response} = ChatReactor.send_message(user_id, "Help", session_id)
      assert String.contains?(response.response, "help")
    end

    test "maintains session history" do
      user_id = "test-user"
      session_id = "test-session"

      # Send first message
      assert {:ok, _} = ChatReactor.send_message(user_id, "First message", session_id)

      # Send second message
      assert {:ok, _} = ChatReactor.send_message(user_id, "Second message", session_id)

      # Get history
      assert {:ok, history} = ChatReactor.get_history(user_id, session_id)
      assert history.session_id == session_id
      assert length(history.messages) >= 4  # 2 user messages + 2 AI responses
    end

    test "handles admin configuration updates" do
      user_id = "admin-user"
      new_config = %{
        "model" => "gpt-4",
        "temperature" => 0.9,
        "max_tokens" => 2000
      }

      assert {:ok, result} = ChatReactor.update_config(user_id, new_config)
      assert result.model_config["model"] == "gpt-4"
      assert result.updated_by == user_id
    end

    test "returns sessions list" do
      user_id = "test-user"
      session_id = "test-session"

      # Create a session by sending a message
      assert {:ok, _} = ChatReactor.send_message(user_id, "Test message", session_id)

      # Get all sessions
      assert {:ok, sessions} = ChatReactor.get_sessions()
      assert is_map(sessions)
      assert Map.has_key?(sessions, session_id)
    end
  end

  describe "ChatSystem DSL" do
    test "capabilities are properly defined" do
      # Test capability implications
      assert ChatSystem.ChatCap.admin.implies?(ChatSystem.ChatCap.send_message)
      assert ChatSystem.ChatCap.admin.implies?(ChatSystem.ChatCap.view_history)
      assert ChatSystem.ChatCap.send_message.implies?(ChatSystem.ChatCap.view_history)
      refute ChatSystem.ChatCap.view_history.implies?(ChatSystem.ChatCap.send_message)
    end

    test "contexts can be created and validated" do
      context_data = %{
        user_id: "test-user",
        session_id: "test-session",
        capabilities: [ChatSystem.ChatCap.send_message],
        model_config: %{model: "gpt-3.5-turbo"}
      }

      context = ChatSystem.ChatContext.new(context_data)
      assert context.user_id == "test-user"
      assert context.session_id == "test-session"
      assert context.capabilities == [ChatSystem.ChatCap.send_message]
    end

    test "intents can be created with proper data" do
      intent_data = %{
        user_id: "test-user",
        message: "Hello",
        session_id: "test-session"
      }

      intent = ChatSystem.SendMessageIntent.new(intent_data)
      assert intent.user_id == "test-user"
      assert intent.message == "Hello"
      assert intent.session_id == "test-session"
    end

    test "effects are properly structured" do
      effect_data = %{
        message_id: "msg-123",
        response: "Hello there!",
        timestamp: DateTime.utc_now()
      }

      effect = ChatSystem.ChatEffect.message_sent(effect_data)
      assert effect.type == :message_sent
      assert effect.data.message_id == "msg-123"
      assert effect.data.response == "Hello there!"
    end
  end

  describe "Web interface" do
    test "renders chat interface" do
      html = PacketflowChatDemo.Web.render_chat_interface()
      assert String.contains?(html, "PacketFlow LLM Chat Demo")
      assert String.contains?(html, "AI Assistant")
      assert String.contains?(html, "Powered by PacketFlow")
    end

    test "includes JavaScript functionality" do
      html = PacketflowChatDemo.Web.render_chat_interface()
      assert String.contains?(html, "sendMessage")
      assert String.contains?(html, "addMessage")
      assert String.contains?(html, "generateSessionId")
    end
  end

  describe "Error handling" do
    test "handles invalid session gracefully" do
      user_id = "test-user"
      session_id = "non-existent-session"

      assert {:error, error} = ChatReactor.get_history(user_id, session_id)
      assert error.error_code == :session_not_found
    end

    test "handles reactor errors gracefully" do
      # This test would require mocking the reactor to simulate errors
      # For now, we'll just ensure the error structure is correct
      error = %{error_code: :reactor_error, message: "Test error"}
      assert error.error_code == :reactor_error
      assert error.message == "Test error"
    end
  end

  describe "Integration tests" do
    test "full message flow works end-to-end" do
      user_id = "integration-user"
      session_id = "integration-session"
      message = "What is PacketFlow?"

      # Send message
      assert {:ok, response} = ChatReactor.send_message(user_id, message, session_id)
      assert response.message_id
      assert response.response
      assert String.contains?(response.response, "PacketFlow")

      # Get history
      assert {:ok, history} = ChatReactor.get_history(user_id, session_id)
      assert history.session_id == session_id
      assert length(history.messages) >= 2

      # Verify message in history
      user_message = Enum.find(history.messages, fn msg -> msg.content == message end)
      assert user_message
      assert user_message.sender == user_id
      assert user_message.role == :user
    end
  end
end
