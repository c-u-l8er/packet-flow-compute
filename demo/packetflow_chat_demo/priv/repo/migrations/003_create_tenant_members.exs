defmodule PacketflowChatDemo.Repo.Migrations.CreateTenantMembers do
  use Ecto.Migration

  def change do
    create table(:tenant_members, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :role, :string, null: false, default: "member"
      add :tenant_id, references(:tenants, type: :binary_id, on_delete: :delete_all), null: false
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:tenant_members, [:tenant_id, :user_id])
    create index(:tenant_members, [:tenant_id])
    create index(:tenant_members, [:user_id])
  end
end
