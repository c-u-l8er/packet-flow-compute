defmodule PacketflowChat.Repo.Migrations.ConvertUserIdsToBinaryId do
  use Ecto.Migration

  def up do
    # First, we need to clear existing data since we can't convert string user_ids to binary_ids
    # Users should re-authenticate after this migration
    execute "DELETE FROM messages"
    execute "DELETE FROM room_members"
    execute "DELETE FROM chat_rooms"

    # Drop and recreate the columns as binary_id
    alter table(:messages) do
      remove :user_id
      add :user_id, :binary_id, null: false
    end

    alter table(:room_members) do
      remove :user_id
      add :user_id, :binary_id, null: false
    end

    alter table(:chat_rooms) do
      remove :created_by
      add :created_by, :binary_id, null: false
    end

    # Recreate the indexes
    create index(:messages, [:user_id])
    create index(:room_members, [:user_id])
    create index(:chat_rooms, [:created_by])
  end

  def down do
    # Reverse the changes by dropping and recreating as string
    alter table(:messages) do
      remove :user_id
      add :user_id, :string, null: false
    end

    alter table(:room_members) do
      remove :user_id
      add :user_id, :string, null: false
    end

    alter table(:chat_rooms) do
      remove :created_by
      add :created_by, :string, null: false
    end

    # Recreate the indexes
    create index(:messages, [:user_id])
    create index(:room_members, [:user_id])
    create index(:chat_rooms, [:created_by])
  end
end
