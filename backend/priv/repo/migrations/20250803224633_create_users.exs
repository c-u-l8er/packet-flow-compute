defmodule PacketflowChat.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    create table(:users, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :clerk_user_id, :string, null: false
      add :username, :string, null: false
      add :email, :string, null: false
      add :avatar_url, :string
      add :created_at, :utc_datetime, default: fragment("now()")
      add :updated_at, :utc_datetime, default: fragment("now()")
    end

    create unique_index(:users, [:clerk_user_id])
    create unique_index(:users, [:username])
    create unique_index(:users, [:email])
  end
end
