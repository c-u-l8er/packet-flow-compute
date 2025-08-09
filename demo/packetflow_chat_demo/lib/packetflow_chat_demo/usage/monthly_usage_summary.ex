defmodule PacketflowChatDemo.Usage.MonthlyUsageSummary do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "monthly_usage_summaries" do
    field :year, :integer
    field :month, :integer

    # Aggregated usage by provider
    field :openai_total_tokens, :integer, default: 0
    field :openai_total_cost_cents, :integer, default: 0
    field :anthropic_total_tokens, :integer, default: 0
    field :anthropic_total_cost_cents, :integer, default: 0
    field :total_requests, :integer, default: 0
    field :successful_requests, :integer, default: 0

    belongs_to :tenant, PacketflowChatDemo.Accounts.Tenant

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(summary, attrs) do
    summary
    |> cast(attrs, [
      :tenant_id, :year, :month,
      :openai_total_tokens, :openai_total_cost_cents,
      :anthropic_total_tokens, :anthropic_total_cost_cents,
      :total_requests, :successful_requests
    ])
    |> validate_required([:tenant_id, :year, :month])
    |> validate_number(:year, greater_than: 2020, less_than: 3000)
    |> validate_number(:month, greater_than: 0, less_than: 13)
    |> validate_number(:openai_total_tokens, greater_than_or_equal_to: 0)
    |> validate_number(:openai_total_cost_cents, greater_than_or_equal_to: 0)
    |> validate_number(:anthropic_total_tokens, greater_than_or_equal_to: 0)
    |> validate_number(:anthropic_total_cost_cents, greater_than_or_equal_to: 0)
    |> validate_number(:total_requests, greater_than_or_equal_to: 0)
    |> validate_number(:successful_requests, greater_than_or_equal_to: 0)
    |> unique_constraint([:tenant_id, :year, :month])
    |> foreign_key_constraint(:tenant_id)
  end

  @doc """
  Gets total cost in dollars for the month.
  """
  def total_cost_dollars(%__MODULE__{} = summary) do
    total_cents = summary.openai_total_cost_cents + summary.anthropic_total_cost_cents
    total_cents / 100.0
  end

  @doc """
  Gets success rate as a percentage.
  """
  def success_rate(%__MODULE__{total_requests: 0}), do: 0.0
  def success_rate(%__MODULE__{} = summary) do
    Float.round(summary.successful_requests / summary.total_requests * 100, 2)
  end

  @doc """
  Gets month name from month number.
  """
  def month_name(%__MODULE__{month: month}) do
    case month do
      1 -> "January"
      2 -> "February"
      3 -> "March"
      4 -> "April"
      5 -> "May"
      6 -> "June"
      7 -> "July"
      8 -> "August"
      9 -> "September"
      10 -> "October"
      11 -> "November"
      12 -> "December"
    end
  end
end
