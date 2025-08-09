defmodule PacketflowChatDemo.Repo.Migrations.RemoveApiKeysFromTenants do
  use Ecto.Migration

  def change do
    alter table(:tenants) do
      remove :openai_api_key, :string
      remove :anthropic_api_key, :string
      remove :google_api_key, :string
      remove :azure_openai_endpoint, :string
      remove :azure_openai_api_key, :string
    end
  end
end
