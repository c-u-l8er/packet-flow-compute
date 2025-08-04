defmodule PacketflowChat.Repo.Migrations.RemoveClerkUserIdFromUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      remove :clerk_user_id, :string
    end
  end
end
