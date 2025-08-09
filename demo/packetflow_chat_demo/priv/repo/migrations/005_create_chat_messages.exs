defmodule PacketflowChatDemo.Repo.Migrations.CreateChatMessages do
  use Ecto.Migration

  def change do
    create table(:chat_messages, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :content, :text, null: false
      add :role, :string, null: false, default: "user"
      add :token_count, :integer
      add :model_used, :string
      add :metadata, :map, default: %{}
      add :session_id, references(:chat_sessions, type: :binary_id, on_delete: :delete_all), null: false
      add :user_id, references(:users, type: :binary_id, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    create index(:chat_messages, [:session_id])
    create index(:chat_messages, [:user_id])
  end
end
