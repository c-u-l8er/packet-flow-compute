defmodule PacketflowChatDemo.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    create table(:users, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :email, :string, null: false
      add :username, :string, null: false
      add :password_hash, :string, null: false
      add :first_name, :string
      add :last_name, :string
      add :avatar_url, :string
      add :is_active, :boolean, default: true, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:users, [:email])
    create unique_index(:users, [:username])
  end
end
