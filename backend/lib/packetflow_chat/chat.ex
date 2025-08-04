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
    |> case do
      {:error, changeset} ->
        # If it's a unique constraint violation, the user is already in the room
        case changeset.errors do
          [room_id: {_, [constraint: :unique, constraint_name: _]}] ->
            {:ok, :already_member}
          _ ->
            {:error, changeset}
        end
      result -> result
    end
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

  @doc """
  Gets room members with detailed user information.
  """
  def list_room_members_with_users(room_id) do
    from(rm in RoomMember,
      where: rm.room_id == ^room_id,
      join: u in PacketflowChat.Accounts.User,
      on: rm.user_id == u.id,
      select: %{
        user_id: u.id,
        username: u.username,
        email: u.email,
        avatar_url: u.avatar_url,
        role: rm.role,
        joined_at: rm.joined_at
      },
      order_by: [desc: rm.joined_at]
    )
    |> Repo.all()
  end

  @doc """
  Gets a user's role in a room.
  """
  def get_user_room_role(room_id, user_id) do
    from(rm in RoomMember,
      where: rm.room_id == ^room_id and rm.user_id == ^user_id,
      select: rm.role,
      order_by: [desc: rm.joined_at],
      limit: 1
    )
    |> Repo.one()
  end

  @doc """
  Updates a user's role in a room (admin only).
  """
  def update_room_member_role(room_id, user_id, new_role, requester_user_id) do
    # Check if requester is admin
    case get_user_room_role(room_id, requester_user_id) do
      "admin" ->
        from(rm in RoomMember,
          where: rm.room_id == ^room_id and rm.user_id == ^user_id
        )
        |> Repo.update_all(set: [role: new_role])
        |> case do
          {1, _} -> {:ok, :updated}
          {0, _} -> {:error, :not_found}
        end

      _ ->
        {:error, :unauthorized}
    end
  end

  @doc """
  Creates a private room with specified members.
  """
  def create_private_room_with_members(attrs, member_user_ids) do
    attrs = Map.put(attrs, "is_private", true)

    case create_room(attrs) do
      {:ok, room} ->
        # Add specified members
        results = Enum.map(member_user_ids, fn user_id ->
          add_room_member(room.id, user_id, "member")
        end)

        # Check if all members were added successfully
        case Enum.all?(results, fn result -> match?({:ok, _}, result) end) do
          true -> {:ok, room}
          false ->
            # Rollback - delete the room if we couldn't add all members
            delete_room(room)
            {:error, :failed_to_add_members}
        end

      error ->
        error
    end
  end

  @doc """
  Checks if a user can manage a room (is admin or creator).
  """
  def can_manage_room?(room_id, user_id) do
    room = get_room!(room_id)
    user_role = get_user_room_role(room_id, user_id)

    room.created_by == user_id or user_role == "admin"
  end
end
