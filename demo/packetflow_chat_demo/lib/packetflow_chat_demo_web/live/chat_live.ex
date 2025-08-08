defmodule PacketflowChatDemoWeb.ChatLive do
  use PacketflowChatDemoWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    socket = assign(socket,
      messages: [],
      current_message: "",
      session_id: generate_session_id(),
      user_id: "demo-user-#{random_string(9)}",
      is_typing: false,
      show_admin_panel: false,
      streaming_message: nil,
      streaming_content: ""
    )

    {:ok, socket}
  end

  @impl true
  def handle_event("send_message", %{"message" => message}, socket) do
    if String.trim(message) != "" do
      # Add user message
      user_message = %{
        id: generate_message_id(),
        sender: socket.assigns.user_id,
        content: message,
        role: :user,
        timestamp: DateTime.utc_now()
      }

      socket = assign(socket,
        messages: [user_message | socket.assigns.messages],
        current_message: "",
        is_typing: true,
        streaming_message: nil,
        streaming_content: ""
      )

      # Send streaming message to PacketFlow reactor
      case PacketflowChatDemo.ChatReactor.stream_message(
        socket.assigns.user_id,
        message,
        socket.assigns.session_id
      ) do
        {:ok, response} ->
          # Subscribe to the stream
          stream_id = response.stream_id
          Phoenix.PubSub.subscribe(PacketflowChatDemo.PubSub, "chat_stream:#{stream_id}")

          # Create placeholder streaming message
          streaming_message = %{
            id: generate_message_id(),
            sender: "ai",
            content: "",
            role: :assistant,
            timestamp: DateTime.utc_now(),
            is_streaming: true
          }

          socket = assign(socket,
            messages: [streaming_message | socket.assigns.messages],
            streaming_message: streaming_message,
            streaming_content: ""
          )

          {:noreply, socket}

        {:error, error} ->
          error_message = %{
            id: generate_message_id(),
            sender: "system",
            content: "Error: #{error.message || "Unknown error"}",
            role: :system,
            timestamp: DateTime.utc_now()
          }

          socket = assign(socket,
            messages: [error_message | socket.assigns.messages],
            is_typing: false
          )

          {:noreply, socket}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("update_message", %{"value" => message}, socket) do
    {:noreply, assign(socket, current_message: message)}
  end

  @impl true
  def handle_event("new_chat", _params, socket) do
    socket = assign(socket,
      messages: [],
      session_id: generate_session_id()
    )

    # Add welcome message
    welcome_message = %{
      id: generate_message_id(),
      sender: "ai",
      content: "New chat session started! How can I help you today?",
      role: :assistant,
      timestamp: DateTime.utc_now()
    }

    socket = assign(socket, messages: [welcome_message])

    {:noreply, socket}
  end

  @impl true
  def handle_event("toggle_admin_panel", _params, socket) do
    {:noreply, assign(socket, show_admin_panel: !socket.assigns.show_admin_panel)}
  end

  @impl true
  def handle_event("update_config", %{"config" => config_text}, socket) do
    case Jason.decode(config_text) do
      {:ok, config} ->
        case PacketflowChatDemo.ChatReactor.update_config(socket.assigns.user_id, config) do
          {:ok, _} ->
            socket = put_flash(socket, :info, "Configuration updated successfully!")
            {:noreply, socket}
          {:error, error} ->
            socket = put_flash(socket, :error, "Failed to update configuration: #{error}")
            {:noreply, socket}
        end
      {:error, _} ->
        socket = put_flash(socket, :error, "Invalid JSON configuration")
        {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:stream_started, _stream_id}, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_info({:stream_chunk, _stream_id, content}, socket) do
    if socket.assigns.streaming_message do
      updated_content = socket.assigns.streaming_content <> content

      # Update the streaming message content
      updated_messages =
        socket.assigns.messages
        |> Enum.map(fn msg ->
          if msg.id == socket.assigns.streaming_message.id do
            %{msg | content: updated_content}
          else
            msg
          end
        end)

      socket = assign(socket,
        messages: updated_messages,
        streaming_content: updated_content
      )

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:stream_ended, _stream_id}, socket) do
    if socket.assigns.streaming_message do
      # Mark the streaming message as complete
      updated_messages =
        socket.assigns.messages
        |> Enum.map(fn msg ->
          if msg.id == socket.assigns.streaming_message.id do
            Map.delete(msg, :is_streaming)
          else
            msg
          end
        end)

      socket = assign(socket,
        messages: updated_messages,
        streaming_message: nil,
        streaming_content: "",
        is_typing: false
      )

      {:noreply, socket}
    else
      {:noreply, assign(socket, is_typing: false)}
    end
  end

  @impl true
  def handle_info({:stream_error, _stream_id, reason}, socket) do
    error_message = %{
      id: generate_message_id(),
      sender: "system",
      content: "Streaming error: #{inspect(reason)}",
      role: :system,
      timestamp: DateTime.utc_now()
    }

    socket = assign(socket,
      messages: [error_message | socket.assigns.messages],
      streaming_message: nil,
      streaming_content: "",
      is_typing: false
    )

    {:noreply, socket}
  end

  # Helper functions
  defp generate_session_id do
    random_string(9)
  end

  defp generate_message_id do
    :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)
  end

  defp random_string(length) do
    :crypto.strong_rand_bytes(length) |> Base.encode16(case: :lower)
  end

  # Helper function for message bubble styling
  defp message_bubble_class(:user), do: "bg-blue-500 text-white"
  defp message_bubble_class(:assistant), do: "bg-gray-100 text-gray-800"
  defp message_bubble_class(:system), do: "bg-red-100 text-red-800"
  defp message_bubble_class(_), do: "bg-gray-100 text-gray-800"
end
