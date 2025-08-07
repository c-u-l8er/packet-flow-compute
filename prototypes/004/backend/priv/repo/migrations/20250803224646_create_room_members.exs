defmodule PacketflowChat.Repo.Migrations.CreateRoomMembers do
  use Ecto.Migration

  def change do
    create table(:room_members, primary_key: false) do
      add :room_id, :binary_id, null: false
      add :user_id, :string, null: false
      add :joined_at, :utc_datetime, default: fragment("now()")
      add :role, :string, default: "member"
    end

    create unique_index(:room_members, [:room_id, :user_id])
    create index(:room_members, [:user_id])
  end
end
