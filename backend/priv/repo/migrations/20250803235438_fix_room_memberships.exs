defmodule PacketflowChat.Repo.Migrations.FixRoomMemberships do
  use Ecto.Migration

  def change do
    # Delete existing incorrect room memberships
    execute("DELETE FROM room_members WHERE user_id = 'user_123'")

    # Add correct room memberships using actual database user IDs (cast UUID to string)
    execute("""
      INSERT INTO room_members (room_id, user_id, joined_at)
      SELECT r.id, u.id::text, NOW()
      FROM chat_rooms r
      CROSS JOIN users u
      WHERE u.clerk_user_id = 'user_123'
      AND r.created_by = 'system'
      AND NOT EXISTS (
        SELECT 1 FROM room_members rm
        WHERE rm.room_id = r.id AND rm.user_id = u.id::text
      )
    """)
  end
end
