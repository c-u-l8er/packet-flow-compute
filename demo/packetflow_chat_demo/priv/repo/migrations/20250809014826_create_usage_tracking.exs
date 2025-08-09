defmodule PacketflowChatDemo.Repo.Migrations.CreateUsageTracking do
  use Ecto.Migration

  def change do
    create table(:usage_records, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :tenant_id, references(:tenants, on_delete: :delete_all, type: :binary_id), null: false
      add :user_id, references(:users, on_delete: :delete_all, type: :binary_id), null: false
      add :session_id, references(:chat_sessions, on_delete: :delete_all, type: :binary_id), null: false
      add :message_id, references(:chat_messages, on_delete: :delete_all, type: :binary_id), null: false

      # Model and request details
      add :model, :string, null: false
      add :provider, :string, null: false # "openai", "anthropic", etc.

      # Token usage
      add :prompt_tokens, :integer, null: false, default: 0
      add :completion_tokens, :integer, null: false, default: 0
      add :total_tokens, :integer, null: false, default: 0

      # Cost tracking (in cents to avoid floating point issues)
      add :prompt_cost_cents, :integer, null: false, default: 0
      add :completion_cost_cents, :integer, null: false, default: 0
      add :total_cost_cents, :integer, null: false, default: 0

      # Request metadata
      add :request_duration_ms, :integer
      add :temperature, :float
      add :max_tokens, :integer
      add :success, :boolean, default: true
      add :error_message, :text

      timestamps(type: :utc_datetime)
    end

    create index(:usage_records, [:tenant_id])
    create index(:usage_records, [:user_id])
    create index(:usage_records, [:session_id])
    create index(:usage_records, [:model])
    create index(:usage_records, [:provider])
    create index(:usage_records, [:inserted_at])
    create index(:usage_records, [:tenant_id, :inserted_at])

    # Monthly usage summary table for faster billing queries
    create table(:monthly_usage_summaries, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :tenant_id, references(:tenants, on_delete: :delete_all, type: :binary_id), null: false
      add :year, :integer, null: false
      add :month, :integer, null: false

      # Aggregated usage by provider
      add :openai_total_tokens, :bigint, default: 0
      add :openai_total_cost_cents, :bigint, default: 0
      add :anthropic_total_tokens, :bigint, default: 0
      add :anthropic_total_cost_cents, :bigint, default: 0
      add :total_requests, :bigint, default: 0
      add :successful_requests, :bigint, default: 0

      timestamps(type: :utc_datetime)
    end

    create unique_index(:monthly_usage_summaries, [:tenant_id, :year, :month])
    create index(:monthly_usage_summaries, [:year, :month])
  end
end
