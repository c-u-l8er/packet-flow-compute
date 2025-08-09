defmodule PacketflowChatDemo.Usage.UsageRecord do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "usage_records" do
    field :model, :string
    field :provider, :string

    # Token usage
    field :prompt_tokens, :integer, default: 0
    field :completion_tokens, :integer, default: 0
    field :total_tokens, :integer, default: 0

    # Cost tracking (in cents)
    field :prompt_cost_cents, :integer, default: 0
    field :completion_cost_cents, :integer, default: 0
    field :total_cost_cents, :integer, default: 0

    # Request metadata
    field :request_duration_ms, :integer
    field :temperature, :float
    field :max_tokens, :integer
    field :success, :boolean, default: true
    field :error_message, :string

    belongs_to :tenant, PacketflowChatDemo.Accounts.Tenant
    belongs_to :user, PacketflowChatDemo.Accounts.User
    belongs_to :session, PacketflowChatDemo.Chat.Session
    belongs_to :message, PacketflowChatDemo.Chat.Message

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(usage_record, attrs) do
    usage_record
    |> cast(attrs, [
      :tenant_id, :user_id, :session_id, :message_id,
      :model, :provider,
      :prompt_tokens, :completion_tokens, :total_tokens,
      :prompt_cost_cents, :completion_cost_cents, :total_cost_cents,
      :request_duration_ms, :temperature, :max_tokens,
      :success, :error_message
    ])
    |> validate_required([
      :tenant_id, :user_id, :session_id, :message_id,
      :model, :provider
    ])
    |> validate_inclusion(:provider, ["openai", "anthropic", "google", "azure"])
    |> validate_number(:prompt_tokens, greater_than_or_equal_to: 0)
    |> validate_number(:completion_tokens, greater_than_or_equal_to: 0)
    |> validate_number(:total_tokens, greater_than_or_equal_to: 0)
    |> validate_number(:prompt_cost_cents, greater_than_or_equal_to: 0)
    |> validate_number(:completion_cost_cents, greater_than_or_equal_to: 0)
    |> validate_number(:total_cost_cents, greater_than_or_equal_to: 0)
    |> foreign_key_constraint(:tenant_id)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:session_id)
    |> foreign_key_constraint(:message_id)
  end

  @doc """
  Calculates cost in dollars from cents.
  """
  def cost_in_dollars(%__MODULE__{total_cost_cents: cents}) do
    cents / 100.0
  end

  @doc """
  Gets the provider from a model name.
  """
  def provider_for_model(model) do
    cond do
      String.starts_with?(model, "gpt-") -> "openai"
      String.starts_with?(model, "claude-") -> "anthropic"
      String.starts_with?(model, "gemini-") -> "google"
      true -> "unknown"
    end
  end
end
