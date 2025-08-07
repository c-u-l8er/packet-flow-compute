defmodule PacketflowChat.Repo.Migrations.SeedDefaultRooms do
  use Ecto.Migration

  def change do
    # Create default rooms with known UUIDs for easy frontend reference
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    
    # Define rooms with fixed UUIDs that frontend can reference
    rooms = [
      %{
        id: "550e8400-e29b-41d4-a716-446655440000", # general room UUID
        name: "General",
        description: "General discussion",
        created_by: "system",
        is_private: false,
        created_at: now
      },
      %{
        id: "550e8400-e29b-41d4-a716-446655440001", # random room UUID
        name: "Random",
        description: "Random chat",
        created_by: "system",
        is_private: false,
        created_at: now
      },
      %{
        id: "550e8400-e29b-41d4-a716-446655440002", # tech room UUID
        name: "Tech Talk",
        description: "Technical discussions",
        created_by: "system",
        is_private: false,
        created_at: now
      }
    ]

    # Insert rooms (only if they don't exist)
    Enum.each(rooms, fn room ->
      execute("INSERT INTO chat_rooms (id, name, description, created_by, is_private, created_at) 
               SELECT '#{room.id}', '#{room.name}', '#{room.description}', '#{room.created_by}', #{room.is_private}, '#{DateTime.to_iso8601(room.created_at)}'
               WHERE NOT EXISTS (SELECT 1 FROM chat_rooms WHERE id = '#{room.id}')")
    end)

    # Create room memberships for the system user
    system_user_id = "user_123" # Our mock user ID
    
    Enum.each(rooms, fn room ->
      execute("INSERT INTO room_members (room_id, user_id, joined_at) 
               SELECT '#{room.id}', '#{system_user_id}', '#{DateTime.to_iso8601(now)}'
               WHERE NOT EXISTS (SELECT 1 FROM room_members WHERE room_id = '#{room.id}' AND user_id = '#{system_user_id}')")
    end)
  end
end
