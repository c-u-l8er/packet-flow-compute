defmodule PacketflowChatWeb.RoomChannel do
  use Phoenix.Channel

  alias PacketflowChat.Chat
  alias PacketflowChat.Accounts

  @impl true
  def join("room:" <> room_identifier, _payload, socket) do
    user_id = socket.assigns.user_id

    case Chat.get_room(room_identifier) do
      nil ->
        {:error, %{reason: "room_not_found"}}

      room ->
        case Chat.user_in_room?(room.id, user_id) do
          true ->
            send(self(), :after_join)
            {:ok, assign(socket, :room_id, room.id)}

          false ->
            {:error, %{reason: "unauthorized"}}
        end
    end
  end

  @impl true
  def handle_info(:after_join, socket) do
    user_id = socket.assigns.user_id
    room_id = socket.assigns.room_id

    # Load recent messages
    messages =
      Chat.list_room_messages(room_id, 20)
      |> Enum.map(&format_message/1)

    # Notify others that user joined
    broadcast!(socket, "user_joined", %{
      user_id: user_id,
      timestamp: DateTime.utc_now()
    })

    # Send recent messages to the joining user
    push(socket, "messages_loaded", %{messages: messages})

    {:noreply, socket}
  end

  @impl true
  def handle_in("send_message", %{"content" => content, "message_type" => message_type}, socket) do
    user_id = socket.assigns.user_id
    room_id = socket.assigns.room_id

    case Chat.create_message(%{
           content: content,
           message_type: message_type || "text",
           user_id: user_id,
           room_id: room_id
         }) do
      {:ok, message} ->
        # Broadcast the message to all room members
        broadcast!(socket, "message_received", format_message(message))
        {:reply, {:ok, %{message_id: message.id}}, socket}

      {:error, changeset} ->
        {:reply, {:error, %{errors: format_errors(changeset)}}, socket}
    end
  end

  @impl true
  def handle_in("typing_start", _payload, socket) do
    user_id = socket.assigns.user_id

    broadcast_from!(socket, "typing_indicator", %{
      user_id: user_id,
      typing: true
    })

    {:noreply, socket}
  end

  @impl true
  def handle_in("typing_stop", _payload, socket) do
    user_id = socket.assigns.user_id

    broadcast_from!(socket, "typing_indicator", %{
      user_id: user_id,
      typing: false
    })

    {:noreply, socket}
  end

  @impl true
  def terminate(_reason, socket) do
    user_id = socket.assigns[:user_id]

    if user_id do
      broadcast!(socket, "user_left", %{
        user_id: user_id,
        timestamp: DateTime.utc_now()
      })
    end

    :ok
  end

  defp format_message(message) do
    user = Accounts.get_user_by_clerk_id(message.user_id)

    %{
      id: message.id,
      content: message.content,
      message_type: message.message_type,
      user: %{
        id: user.clerk_user_id,
        username: user.username,
        avatar_url: user.avatar_url
      },
      created_at: message.created_at
    }
  end

  defp format_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end