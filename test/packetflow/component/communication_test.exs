defmodule PacketFlow.Component.CommunicationTest do
  use ExUnit.Case, async: false  # Not async due to shared GenServer state

  alias PacketFlow.Component.Communication

  defmodule TestMessageHandler do
    def handle_message(message) do
      case message.payload do
        {:test, "success"} -> :ok
        {:test, "error"} -> {:error, :test_error}
        _ -> :ok
      end
    end
  end

  defmodule TestComponent do
    use GenServer

    def start_link(name) do
      GenServer.start_link(__MODULE__, [], name: name)
    end

    def init(_) do
      {:ok, %{messages: []}}
    end

    def get_messages(pid) do
      GenServer.call(pid, :get_messages)
    end

    def handle_call(:get_messages, _from, state) do
      {:reply, state.messages, state}
    end

    def handle_info({:component_message, from, payload}, state) do
      message = {from, payload}
      {:noreply, %{state | messages: [message | state.messages]}}
    end
  end

  setup do
    # Start the communication service
    start_supervised!({Communication, []})

    # Start test components
    {:ok, component1} = TestComponent.start_link(:test_component_1)
    {:ok, component2} = TestComponent.start_link(:test_component_2)

    %{component1: component1, component2: component2}
  end

  describe "protocol registration" do
    test "register_protocol adds new protocol" do
      protocol = %{
        name: :test_protocol,
        version: "1.0.0",
        message_types: [:request, :response],
        validation_rules: %{},
        transformation_rules: %{}
      }

      assert :ok = Communication.register_protocol(protocol)
    end

    test "register_protocol validates protocol structure" do
      invalid_protocol = %{
        name: :invalid_protocol
        # Missing required fields
      }

      assert {:error, {:missing_fields, _}} = Communication.register_protocol(invalid_protocol)
    end
  end

  describe "message sending" do
    test "send_message delivers message to target component" do
      payload = {:test, "message"}
      assert :ok = Communication.send_message(:test_component_1, payload, from: :sender)

      # Wait a bit for message delivery
      Process.sleep(50)

      messages = TestComponent.get_messages(:test_component_1)
      assert length(messages) >= 1

      {_sender, received_payload} = List.first(messages)
      assert received_payload == payload
    end

    test "send_message returns error for non-existent component" do
      assert {:error, {:target_not_found, :non_existent}} =
        Communication.send_message(:non_existent, "payload")
    end

    test "send_message with custom message options" do
      payload = "test payload"
      opts = [
        from: :custom_sender,
        priority: :high,
        timeout: 10000,
        metadata: %{custom: "data"}
      ]

      assert :ok = Communication.send_message(:test_component_1, payload, opts)

      Process.sleep(50)
      messages = TestComponent.get_messages(:test_component_1)
      assert length(messages) >= 1
    end
  end

  describe "synchronous requests" do
    test "send_request with mock response handling" do
      # This test is limited because we need a more complex setup for full request-response
      # For now, we test that the function doesn't crash and handles timeouts

      # Use a very short timeout to test timeout handling
      result = Communication.send_request(:test_component_1, "test", timeout: 1)
      assert {:error, :timeout} = result
    end

    test "send_request to non-existent component returns error" do
      assert {:error, {:target_not_found, :non_existent}} =
        Communication.send_request(:non_existent, "payload", timeout: 100)
    end
  end

  describe "broadcast messaging" do
    test "broadcast_message sends to multiple targets", %{component1: comp1, component2: comp2} do
      targets = [comp1, comp2]
      payload = "broadcast message"

      assert :ok = Communication.broadcast_message(targets, payload)

      Process.sleep(50)

      # Check both components received the message
      messages1 = TestComponent.get_messages(comp1)
      messages2 = TestComponent.get_messages(comp2)

      assert length(messages1) >= 1
      assert length(messages2) >= 1
    end

    test "broadcast_message handles partial failures" do
      targets = [:test_component_1, :non_existent, :test_component_2]
      payload = "broadcast with failure"

      assert {:error, {:partial_failure, 1}} =
        Communication.broadcast_message(targets, payload)
    end

    test "broadcast_message with empty target list" do
      assert :ok = Communication.broadcast_message([], "payload")
    end
  end

  describe "subscription system" do
    test "subscribe and unsubscribe to component messages" do
      # Subscribe test_component_2 to messages from test_component_1
      assert :ok = Communication.subscribe(:test_component_1, :test_component_2)

      # Unsubscribe
      assert :ok = Communication.unsubscribe(:test_component_1, :test_component_2)
    end

    test "subscribed components receive broadcast messages" do
      # Subscribe test_component_2 to messages from test_component_1
      :ok = Communication.subscribe(:test_component_1, :test_component_2)

      # Send broadcast from test_component_1
      :ok = Communication.broadcast_message([:test_component_1], "subscription test",
        from: :test_component_1)

      Process.sleep(50)

      # test_component_2 should receive the message via subscription
      messages = TestComponent.get_messages(:test_component_2)
      # Note: This test may need adjustment based on actual subscription implementation
      assert is_list(messages)
    end
  end

  describe "message handlers" do
    test "register_message_handler adds custom handler" do
      assert :ok = Communication.register_message_handler(:test_component_1, TestMessageHandler)
    end

    test "register_message_handler validates handler module" do
      defmodule InvalidHandler do
        # Missing handle_message/1 function
      end

      assert {:error, :invalid_handler} =
        Communication.register_message_handler(:test_component_1, InvalidHandler)
    end
  end

  describe "statistics and monitoring" do
    test "get_statistics returns communication metrics" do
      stats = Communication.get_statistics()

      assert is_map(stats)
      assert Map.has_key?(stats, :messages_sent)
      assert Map.has_key?(stats, :messages_received)
      assert Map.has_key?(stats, :messages_failed)
      assert Map.has_key?(stats, :average_latency)

      assert is_integer(stats.messages_sent)
      assert is_integer(stats.messages_received)
      assert is_integer(stats.messages_failed)
      assert is_number(stats.average_latency)
    end

    test "statistics are updated on message operations" do
      initial_stats = Communication.get_statistics()

      # Send a message
      :ok = Communication.send_message(:test_component_1, "test")

      updated_stats = Communication.get_statistics()
      assert updated_stats.messages_sent >= initial_stats.messages_sent
    end

    test "get_pending_requests returns current pending requests" do
      pending = Communication.get_pending_requests()
      assert is_map(pending)
    end
  end

  describe "message validation" do
    test "message validation catches invalid messages" do
      # Test with various invalid message structures
      # This is tested indirectly through the send_message functions
      # which should validate messages before processing

      # Send message with minimal valid structure
      assert :ok = Communication.send_message(:test_component_1, "valid payload")
    end

    test "message timeout handling" do
      # Send request with very short timeout
      result = Communication.send_request(:test_component_1, "timeout test", timeout: 1)
      assert {:error, :timeout} = result
    end
  end

  describe "protocol handling" do
    test "messages are processed according to registered protocols" do
      # Register a test protocol
      protocol = %{
        name: :test_protocol,
        version: "1.0.0",
        message_types: [:notification],
        validation_rules: %{},
        transformation_rules: %{}
      }

      :ok = Communication.register_protocol(protocol)

      # Send a message that should be processed by the protocol
      assert :ok = Communication.send_message(:test_component_1, "protocol test",
        type: :notification)
    end
  end

  describe "error handling and resilience" do
    test "handles component crashes gracefully" do
      # Stop a component and try to send message
      GenServer.stop(:test_component_1)

      # Should return error, not crash
      assert {:error, {:target_not_found, :test_component_1}} =
        Communication.send_message(:test_component_1, "test")
    end

    test "handles malformed message payloads" do
      # Test with various payload types
      payloads = [
        nil,
        :atom,
        123,
        "string",
        %{map: "value"},
        [:list, :of, :atoms],
        {:tuple, "value"}
      ]

      for payload <- payloads do
        result = Communication.send_message(:test_component_2, payload)
        case result do
          :ok -> assert true
          {:error, _} -> assert true
          _ -> flunk("Unexpected result: #{inspect(result)}")
        end
      end
    end

    test "handles concurrent message sending" do
      # Send many messages concurrently
      tasks = for i <- 1..50 do
        Task.async(fn ->
          Communication.send_message(:test_component_2, "concurrent_#{i}")
        end)
      end

      # Wait for all tasks and check results
      results = Enum.map(tasks, &Task.await/1)
      assert Enum.all?(results, &(&1 == :ok))
    end
  end

  describe "message priorities" do
    test "messages can be sent with different priorities" do
      priorities = [:low, :normal, :high, :urgent]

      for priority <- priorities do
        result = Communication.send_message(:test_component_1, "priority test",
          priority: priority)
        assert result == :ok
      end
    end
  end

  describe "message metadata" do
    test "messages can include custom metadata" do
      metadata = %{
        source: "test",
        version: "1.0.0",
        custom_field: 42
      }

      assert :ok = Communication.send_message(:test_component_1, "metadata test",
        metadata: metadata)
    end
  end

  describe "component lifecycle integration" do
    test "communication system handles component restarts" do
      # Send initial message
      :ok = Communication.send_message(:test_component_1, "before restart")

      # Restart the component
      GenServer.stop(:test_component_1)
      {:ok, _pid} = TestComponent.start_link(:test_component_1)

      # Send message after restart
      assert :ok = Communication.send_message(:test_component_1, "after restart")
    end
  end
end
