defmodule PacketflowChatDemo.Repo.Migrations.CreateChatSessions do
  use Ecto.Migration

  def change do
    create table(:chat_sessions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :title, :string
      add :model, :string
      add :system_prompt, :text
      add :is_active, :boolean, default: true, null: false
      add :tenant_id, references(:tenants, type: :binary_id, on_delete: :delete_all), null: false
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:chat_sessions, [:tenant_id])
    create index(:chat_sessions, [:user_id])
    create index(:chat_sessions, [:tenant_id, :user_id])
  end
end
