defmodule PacketflowChat.Chat do
  @moduledoc """
  The Chat context.
  """

  import Ecto.Query, warn: false
  alias PacketflowChat.Repo
  alias PacketflowChat.Chat.{Room, Message, RoomMember}

  # Room functions

  @doc """
  Returns the list of rooms for a user.
  """
  def list_user_rooms(user_id) do
    from(r in Room,
      join: rm in RoomMember,
      on: rm.room_id == r.id,
      where: rm.user_id == ^user_id,
      order_by: [desc: r.created_at]
    )
    |> Repo.all()
  end

  @doc """
  Returns the list of public rooms.
  """
  def list_public_rooms do
    from(r in Room,
      where: r.is_private == false,
      order_by: [desc: r.created_at]
    )
    |> Repo.all()
  end

  @doc """
  Gets a single room.
  """
  def get_room!(id), do: Repo.get!(Room, id)

  @doc """
  Creates a room.
  """
  def create_room(attrs \\ %{}) do
    %Room{}
    |> Room.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, room} ->
        # Add creator as admin member
        add_room_member(room.id, room.created_by, "admin")
        {:ok, room}

      error ->
        error
    end
  end

  @doc """
  Updates a room.
  """
  def update_room(%Room{} = room, attrs) do
    room
    |> Room.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a room.
  """
  def delete_room(%Room{} = room) do
    Repo.delete(room)
  end

  # Message functions

  @doc """
  Returns messages for a room with pagination.
  """
  def list_room_messages(room_id, limit \\ 50, offset \\ 0) do
    from(m in Message,
      where: m.room_id == ^room_id,
      order_by: [desc: m.created_at],
      limit: ^limit,
      offset: ^offset,
      preload: [:user]
    )
    |> Repo.all()
    |> Enum.reverse()
  end

  @doc """
  Creates a message.
  """
  def create_message(attrs \\ %{}) do
    %Message{}
    |> Message.changeset(attrs)
    |> Repo.insert()
  end

  # Room member functions

  @doc """
  Adds a user to a room.
  """
  def add_room_member(room_id, user_id, role \\ "member") do
    %RoomMember{}
    |> RoomMember.changeset(%{
      room_id: room_id,
      user_id: user_id,
      role: role
    })
    |> Repo.insert()
  end

  @doc """
  Removes a user from a room.
  """
  def remove_room_member(room_id, user_id) do
    from(rm in RoomMember,
      where: rm.room_id == ^room_id and rm.user_id == ^user_id
    )
    |> Repo.delete_all()
  end

  @doc """
  Gets a room by name (case-insensitive).
  """
  def get_room_by_name(name) do
    from(r in Room,
      where: ilike(r.name, ^name)
    )
    |> Repo.one()
  end

  @doc """
  Gets a room by ID or name.
  """
  def get_room(room_identifier) do
    case Ecto.UUID.cast(room_identifier) do
      {:ok, uuid} ->
        # It's a valid UUID, look up by ID
        Repo.get(Room, uuid)
      
      :error ->
        # It's not a UUID, look up by name
        get_room_by_name(room_identifier)
    end
  end

  @doc """
  Checks if a user is a member of a room.
  """
  def user_in_room?(room_id, user_id) do
    from(rm in RoomMember,
      where: rm.room_id == ^room_id and rm.user_id == ^user_id
    )
    |> Repo.exists?()
  end

  @doc """
  Gets room members.
  """
  def list_room_members(room_id) do
    from(rm in RoomMember,
      where: rm.room_id == ^room_id,
      preload: [:user]
    )
    |> Repo.all()
  end
end