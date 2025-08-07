defmodule PacketflowChat.Repo.Migrations.AddAuthenticationToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      # Add password hashing field
      add :hashed_password, :string, null: true

      # Add confirmation fields
      add :confirmed_at, :naive_datetime

      # Make clerk_user_id optional since we'll support both auth methods
      modify :clerk_user_id, :string, null: true
    end

    # Remove the unique constraint on clerk_user_id temporarily
    drop unique_index(:users, [:clerk_user_id])

    # Add it back but allow nulls
    create unique_index(:users, [:clerk_user_id], where: "clerk_user_id IS NOT NULL")

    # Create user tokens table for session management
    create table(:users_tokens, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :token, :binary, null: false
      add :context, :string, null: false
      add :sent_to, :string
      timestamps(updated_at: false)
    end

    create index(:users_tokens, [:user_id])
    create unique_index(:users_tokens, [:context, :token])
  end
end
