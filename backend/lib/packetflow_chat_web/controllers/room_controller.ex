defmodule PacketflowChatWeb.RoomController do
  use PacketflowChatWeb, :controller

  alias PacketflowChat.Chat

  action_fallback PacketflowChatWeb.FallbackController

  def index(conn, _params) do
    user_id = conn.assigns.current_user_id
    rooms = Chat.list_user_rooms(user_id)

    json(conn, %{
      rooms: Enum.map(rooms, &format_room/1)
    })
  end

  def public_rooms(conn, _params) do
    rooms = Chat.list_public_rooms()

    json(conn, %{
      rooms: Enum.map(rooms, &format_room/1)
    })
  end

  def show(conn, %{"id" => id}) do
    user_id = conn.assigns.current_user_id

    case Chat.user_in_room?(id, user_id) do
      true ->
        room = Chat.get_room!(id)
        messages = Chat.list_room_messages(id, 50)

        json(conn, %{
          room: format_room(room),
          messages: Enum.map(messages, &format_message/1)
        })

      false ->
        conn
        |> put_status(:forbidden)
        |> json(%{error: "Access denied"})
    end
  end

  def create(conn, room_params) do
    user_id = conn.assigns.current_user_id
    room_params = Map.put(room_params, "created_by", user_id)

    case Chat.create_room(room_params) do
      {:ok, room} ->
        conn
        |> put_status(:created)
        |> json(%{room: format_room(room)})

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: format_errors(changeset)})
    end
  end

  def join(conn, %{"id" => room_id}) do
    user_id = conn.assigns.current_user_id

    case Chat.add_room_member(room_id, user_id) do
      {:ok, _room_member} ->
        json(conn, %{message: "Successfully joined room"})

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: format_errors(changeset)})
    end
  end

  def leave(conn, %{"id" => room_id}) do
    user_id = conn.assigns.current_user_id

    case Chat.remove_room_member(room_id, user_id) do
      {1, _} ->
        json(conn, %{message: "Successfully left room"})

      {0, _} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Not a member of this room"})
    end
  end

  defp format_room(room) do
    %{
      id: room.id,
      name: room.name,
      description: room.description,
      is_private: room.is_private,
      created_by: room.created_by,
      created_at: room.created_at
    }
  end

  defp format_message(message) do
    %{
      id: message.id,
      content: message.content,
      message_type: message.message_type,
      user_id: message.user_id,
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