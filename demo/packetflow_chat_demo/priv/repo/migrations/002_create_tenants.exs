defmodule PacketflowChatDemo.Repo.Migrations.CreateTenants do
  use Ecto.Migration

  def change do
    create table(:tenants, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :slug, :string, null: false
      add :description, :text
      add :logo_url, :string
      add :is_active, :boolean, default: true, null: false

      # LLM API Configuration
      add :openai_api_key, :string
      add :anthropic_api_key, :string
      add :google_api_key, :string
      add :azure_openai_endpoint, :string
      add :azure_openai_api_key, :string

      # Chat Settings
      add :default_model, :string, default: "gpt-3.5-turbo"
      add :max_tokens, :integer, default: 1000
      add :temperature, :float, default: 0.7
      add :allow_model_selection, :boolean, default: true

      timestamps(type: :utc_datetime)
    end

    create unique_index(:tenants, [:slug])
  end
end
