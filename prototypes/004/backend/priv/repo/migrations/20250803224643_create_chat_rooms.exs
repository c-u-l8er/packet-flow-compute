defmodule PacketflowChat.Repo.Migrations.CreateChatRooms do
  use Ecto.Migration

  def change do
    create table(:chat_rooms, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :description, :text
      add :created_by, :string, null: false
      add :is_private, :boolean, default: false
      add :created_at, :utc_datetime, default: fragment("now()")
    end

    create index(:chat_rooms, [:created_by])
    create index(:chat_rooms, [:is_private])
  end
end
