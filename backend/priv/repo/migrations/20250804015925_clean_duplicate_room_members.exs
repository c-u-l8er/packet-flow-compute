defmodule PacketflowChat.Repo.Migrations.CleanDuplicateRoomMembers do
  use Ecto.Migration

  def up do
    # Remove duplicate room members, keeping the one with the latest joined_at timestamp
    execute """
    DELETE FROM room_members
    WHERE (room_id, user_id, joined_at) NOT IN (
      SELECT room_id, user_id, MAX(joined_at)
      FROM room_members
      GROUP BY room_id, user_id
    )
    """
  end

  def down do
    # This migration cannot be reversed as we're deleting duplicate data
    :ok
  end
end
