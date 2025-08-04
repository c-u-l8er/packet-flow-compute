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

  def members(conn, %{"id" => room_id}) do
    user_id = conn.assigns.current_user_id

    case Chat.user_in_room?(room_id, user_id) do
      true ->
        members = Chat.list_room_members_with_users(room_id)
        json(conn, %{members: members})

      false ->
        conn
        |> put_status(:forbidden)
        |> json(%{error: "Access denied"})
    end
  end

  def invite_user(conn, %{"id" => room_id, "user_id" => invited_user_id}) do
    user_id = conn.assigns.current_user_id

    case Chat.can_manage_room?(room_id, user_id) do
      true ->
        case Chat.add_room_member(room_id, invited_user_id, "member") do
          {:ok, _room_member} ->
            json(conn, %{message: "User invited successfully"})

          {:error, changeset} ->
            conn
            |> put_status(:unprocessable_entity)
            |> json(%{errors: format_errors(changeset)})
        end

      false ->
        conn
        |> put_status(:forbidden)
        |> json(%{error: "Only room admins can invite users"})
    end
  end

  def remove_user(conn, %{"id" => room_id, "user_id" => removed_user_id}) do
    user_id = conn.assigns.current_user_id

    case Chat.can_manage_room?(room_id, user_id) do
      true ->
        case Chat.remove_room_member(room_id, removed_user_id) do
          {1, _} ->
            json(conn, %{message: "User removed successfully"})

          {0, _} ->
            conn
            |> put_status(:not_found)
            |> json(%{error: "User not found in room"})
        end

      false ->
        conn
        |> put_status(:forbidden)
        |> json(%{error: "Only room admins can remove users"})
    end
  end

  def update_user_role(conn, %{"id" => room_id, "user_id" => target_user_id, "role" => new_role}) do
    user_id = conn.assigns.current_user_id

    case Chat.update_room_member_role(room_id, target_user_id, new_role, user_id) do
      {:ok, :updated} ->
        json(conn, %{message: "User role updated successfully"})

      {:error, :unauthorized} ->
        conn
        |> put_status(:forbidden)
        |> json(%{error: "Only room admins can update roles"})

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "User not found in room"})
    end
  end

  def create_private_with_users(conn, %{"name" => name, "user_ids" => user_ids} = params) do
    user_id = conn.assigns.current_user_id
    description = Map.get(params, "description", "")

    room_attrs = %{
      "name" => name,
      "description" => description,
      "created_by" => user_id
    }

    # Include the creator in the member list
    all_user_ids = [user_id | user_ids] |> Enum.uniq()

    case Chat.create_private_room_with_members(room_attrs, all_user_ids) do
      {:ok, room} ->
        conn
        |> put_status(:created)
        |> json(%{room: format_room(room)})

      {:error, :failed_to_add_members} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Failed to add some members to the room"})

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: format_errors(changeset)})
    end
  end

  def delete(conn, %{"id" => room_id}) do
    user_id = conn.assigns.current_user_id

    case Chat.can_manage_room?(room_id, user_id) do
      true ->
        room = Chat.get_room!(room_id)

        case Chat.delete_room(room) do
          {:ok, _room} ->
            json(conn, %{message: "Room deleted successfully"})

          {:error, changeset} ->
            conn
            |> put_status(:unprocessable_entity)
            |> json(%{errors: format_errors(changeset)})
        end

      false ->
        conn
        |> put_status(:forbidden)
        |> json(%{error: "Only room admins can delete rooms"})
    end
  rescue
    Ecto.NoResultsError ->
      conn
      |> put_status(:not_found)
      |> json(%{error: "Room not found"})
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
