defmodule PacketflowChat.Repo.Migrations.CreateMessages do
  use Ecto.Migration

  def change do
    create table(:messages, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :room_id, :binary_id, null: false
      add :user_id, :string, null: false
      add :content, :text, null: false
      add :message_type, :string, default: "text"
      add :created_at, :utc_datetime, default: fragment("now()")
    end

    create index(:messages, [:room_id])
    create index(:messages, [:user_id])
    create index(:messages, [:created_at])
  end
end
