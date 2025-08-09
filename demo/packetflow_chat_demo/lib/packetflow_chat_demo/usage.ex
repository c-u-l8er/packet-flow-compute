defmodule PacketflowChatDemo.Usage do
  @moduledoc """
  The Usage context - tracks API usage and costs for billing.
  """

  import Ecto.Query, warn: false
  alias PacketflowChatDemo.Repo

  alias PacketflowChatDemo.Usage.{UsageRecord, MonthlyUsageSummary}

  @doc """
  Records usage for a chat message.
  """
  def record_usage(attrs) do
    %UsageRecord{}
    |> UsageRecord.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, record} ->
        # Update monthly summary asynchronously
        Task.start(fn -> update_monthly_summary(record) end)
        {:ok, record}
      error -> error
    end
  end

  @doc """
  Gets usage records for a tenant within a date range.
  """
  def get_tenant_usage(tenant_id, start_date, end_date) do
    from(u in UsageRecord,
      where: u.tenant_id == ^tenant_id,
      where: u.inserted_at >= ^start_date and u.inserted_at <= ^end_date,
      order_by: [desc: u.inserted_at]
    )
    |> Repo.all()
  end

  @doc """
  Gets monthly usage summary for a tenant.
  """
  def get_monthly_summary(tenant_id, year, month) do
    Repo.get_by(MonthlyUsageSummary, tenant_id: tenant_id, year: year, month: month)
  end

  @doc """
  Gets all monthly summaries for a tenant.
  """
  def get_tenant_monthly_summaries(tenant_id) do
    from(s in MonthlyUsageSummary,
      where: s.tenant_id == ^tenant_id,
      order_by: [desc: s.year, desc: s.month]
    )
    |> Repo.all()
  end

  @doc """
  Calculates total cost for a tenant in a given month.
  """
  def calculate_monthly_cost(tenant_id, year, month) do
    case get_monthly_summary(tenant_id, year, month) do
      nil -> {:ok, 0}
      summary ->
        total_cents = summary.openai_total_cost_cents + summary.anthropic_total_cost_cents
        {:ok, total_cents}
    end
  end

  @doc """
  Gets usage statistics for a tenant.
  """
  def get_tenant_stats(tenant_id) do
    current_month = Date.utc_today()

    # Current month usage
    current_summary = get_monthly_summary(tenant_id, current_month.year, current_month.month)

    # Total usage across all time
    total_query = from(u in UsageRecord,
      where: u.tenant_id == ^tenant_id,
      select: %{
        total_requests: count(u.id),
        total_tokens: sum(u.total_tokens),
        total_prompt_tokens: sum(u.prompt_tokens),
        total_completion_tokens: sum(u.completion_tokens),
        total_cost_cents: sum(u.total_cost_cents),
        total_prompt_cost_cents: sum(u.prompt_cost_cents),
        total_completion_cost_cents: sum(u.completion_cost_cents),
        successful_requests: fragment("COUNT(CASE WHEN ? THEN 1 END)", u.success)
      }
    )

    total_stats = Repo.one(total_query) || %{
      total_requests: 0,
      total_tokens: 0,
      total_prompt_tokens: 0,
      total_completion_tokens: 0,
      total_cost_cents: 0,
      total_prompt_cost_cents: 0,
      total_completion_cost_cents: 0,
      successful_requests: 0
    }

    # Model usage breakdown
    model_stats_query = from(u in UsageRecord,
      where: u.tenant_id == ^tenant_id,
      group_by: u.model,
      select: %{
        model: u.model,
        requests: count(u.id),
        tokens: sum(u.total_tokens),
        cost_cents: sum(u.total_cost_cents)
      }
    )

    model_stats = Repo.all(model_stats_query)

    # Daily usage for last 30 days
    thirty_days_ago = Date.add(Date.utc_today(), -30)
    daily_stats_query = from(u in UsageRecord,
      where: u.tenant_id == ^tenant_id,
      where: fragment("date(?)", u.inserted_at) >= ^thirty_days_ago,
      group_by: fragment("date(?)", u.inserted_at),
      select: %{
        date: fragment("date(?)", u.inserted_at),
        requests: count(u.id),
        tokens: sum(u.total_tokens),
        cost_cents: sum(u.total_cost_cents)
      },
      order_by: [asc: fragment("date(?)", u.inserted_at)]
    )

    daily_stats = Repo.all(daily_stats_query)

    # Average cost per request
    avg_cost_per_request = if (total_stats.total_requests || 0) > 0 do
      Float.round((total_stats.total_cost_cents || 0) / (total_stats.total_requests || 1) / 100, 4)
    else
      0.0
    end

    # Average tokens per request
    avg_tokens_per_request = if (total_stats.total_requests || 0) > 0 do
      Float.round((total_stats.total_tokens || 0) / (total_stats.total_requests || 1), 1)
    else
      0.0
    end

    %{
      current_month: current_summary,
      total: total_stats,
      success_rate: if (total_stats.total_requests || 0) > 0 do
        Float.round((total_stats.successful_requests || 0) / (total_stats.total_requests || 1) * 100, 2)
      else
        0.0
      end,
      model_breakdown: model_stats,
      daily_usage: daily_stats,
      avg_cost_per_request: avg_cost_per_request,
      avg_tokens_per_request: avg_tokens_per_request,
      token_efficiency: %{
        prompt_tokens: total_stats.total_prompt_tokens || 0,
        completion_tokens: total_stats.total_completion_tokens || 0,
        prompt_cost_ratio: if (total_stats.total_cost_cents || 0) > 0 do
          Float.round((total_stats.total_prompt_cost_cents || 0) / (total_stats.total_cost_cents || 1) * 100, 1)
        else
          0.0
        end
      }
    }
  end

  # Private function to update monthly summary
  defp update_monthly_summary(%UsageRecord{} = record) do
    date = DateTime.to_date(record.inserted_at)

    # Find or create monthly summary
    summary = case get_monthly_summary(record.tenant_id, date.year, date.month) do
      nil ->
        %MonthlyUsageSummary{}
        |> MonthlyUsageSummary.changeset(%{
          tenant_id: record.tenant_id,
          year: date.year,
          month: date.month
        })
        |> Repo.insert!()

      existing -> existing
    end

    # Update the summary with new usage
    updates = case record.provider do
      "openai" ->
        %{
          openai_total_tokens: summary.openai_total_tokens + record.total_tokens,
          openai_total_cost_cents: summary.openai_total_cost_cents + record.total_cost_cents
        }
      "anthropic" ->
        %{
          anthropic_total_tokens: summary.anthropic_total_tokens + record.total_tokens,
          anthropic_total_cost_cents: summary.anthropic_total_cost_cents + record.total_cost_cents
        }
      _ ->
        %{}
    end

    updates = Map.merge(updates, %{
      total_requests: summary.total_requests + 1,
      successful_requests: summary.successful_requests + (if record.success, do: 1, else: 0)
    })

    summary
    |> MonthlyUsageSummary.changeset(updates)
    |> Repo.update()
  end
end
