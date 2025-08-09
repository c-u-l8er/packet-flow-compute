defmodule PacketflowChatDemo.Analytics do
  @moduledoc """
  Analytics context for generating chat and usage statistics.
  """

  import Ecto.Query, warn: false
  alias PacketflowChatDemo.Repo
  alias PacketflowChatDemo.{Chat, Usage, Accounts}
  alias PacketflowChatDemo.Chat.{Session, Message}
  alias PacketflowChatDemo.Usage.UsageRecord

  @doc """
  Gets comprehensive analytics for a tenant.
  """
  def get_tenant_analytics(tenant_id, opts \\ []) do
    days = Keyword.get(opts, :days, 30)
    start_date = Date.utc_today() |> Date.add(-days)

    %{
      overview: get_overview_stats(tenant_id, start_date),
      usage: get_usage_stats(tenant_id, start_date),
      activity: get_activity_stats(tenant_id, start_date),
      models: get_model_stats(tenant_id, start_date),
      users: get_user_stats(tenant_id, start_date),
      trends: get_trend_data(tenant_id, start_date)
    }
  end

  @doc """
  Gets overview statistics for a tenant.
  """
  def get_overview_stats(tenant_id, start_date \\ nil) do
    start_date = start_date || Date.utc_today() |> Date.add(-30)
    start_datetime = DateTime.new!(start_date, ~T[00:00:00], "Etc/UTC")

    # Total sessions and messages
    sessions_query = from(s in Session,
      where: s.tenant_id == ^tenant_id and s.inserted_at >= ^start_datetime)

    messages_query = from(m in Message,
      join: s in Session, on: s.id == m.session_id,
      where: s.tenant_id == ^tenant_id and m.inserted_at >= ^start_datetime)

    usage_query = from(u in UsageRecord,
      where: u.tenant_id == ^tenant_id and u.inserted_at >= ^start_datetime)

    total_sessions = Repo.aggregate(sessions_query, :count)
    total_messages = Repo.aggregate(messages_query, :count)

    # Active sessions (had messages in period)
    active_sessions = from(s in Session,
      join: m in Message, on: s.id == m.session_id,
      where: s.tenant_id == ^tenant_id and m.inserted_at >= ^start_datetime,
      distinct: s.id
    ) |> Repo.aggregate(:count)

    # Usage totals
    usage_totals = from(u in usage_query,
      select: %{
        total_tokens: sum(u.total_tokens),
        total_cost_cents: sum(u.total_cost_cents),
        total_requests: count(u.id),
        successful_requests: count(u.id) |> filter(u.success == true)
      }
    ) |> Repo.one() || %{total_tokens: 0, total_cost_cents: 0, total_requests: 0, successful_requests: 0}

    # Average session length (messages per session)
    avg_session_length = if total_sessions > 0, do: total_messages / total_sessions, else: 0

    %{
      total_sessions: total_sessions,
      active_sessions: active_sessions,
      total_messages: total_messages,
      avg_session_length: Float.round(avg_session_length, 1),
      total_tokens: usage_totals.total_tokens || 0,
      total_cost: (usage_totals.total_cost_cents || 0) / 100.0,
      total_requests: usage_totals.total_requests || 0,
      success_rate: calculate_success_rate(usage_totals.successful_requests, usage_totals.total_requests)
    }
  end

  @doc """
  Gets usage statistics broken down by provider and model.
  """
  def get_usage_stats(tenant_id, start_date \\ nil) do
    start_date = start_date || Date.utc_today() |> Date.add(-30)
    start_datetime = DateTime.new!(start_date, ~T[00:00:00], "Etc/UTC")

    # Usage by provider
    provider_stats = from(u in UsageRecord,
      where: u.tenant_id == ^tenant_id and u.inserted_at >= ^start_datetime,
      group_by: u.provider,
      select: %{
        provider: u.provider,
        total_tokens: sum(u.total_tokens),
        total_cost_cents: sum(u.total_cost_cents),
        request_count: count(u.id)
      }
    ) |> Repo.all()

    # Usage by model
    model_stats = from(u in UsageRecord,
      where: u.tenant_id == ^tenant_id and u.inserted_at >= ^start_datetime,
      group_by: u.model,
      select: %{
        model: u.model,
        total_tokens: sum(u.total_tokens),
        total_cost_cents: sum(u.total_cost_cents),
        request_count: count(u.id),
        avg_duration_ms: avg(u.request_duration_ms)
      },
      order_by: [desc: sum(u.total_tokens)]
    ) |> Repo.all()

    %{
      by_provider: Enum.map(provider_stats, &format_usage_stat/1),
      by_model: Enum.map(model_stats, &format_model_stat/1)
    }
  end

  @doc """
  Gets activity statistics showing usage patterns over time.
  """
  def get_activity_stats(tenant_id, start_date \\ nil) do
    start_date = start_date || Date.utc_today() |> Date.add(-30)
    start_datetime = DateTime.new!(start_date, ~T[00:00:00], "Etc/UTC")

    # Daily message counts
    daily_messages = from(m in Message,
      join: s in Session, on: s.id == m.session_id,
      where: s.tenant_id == ^tenant_id and m.inserted_at >= ^start_datetime,
      group_by: fragment("DATE(?)", m.inserted_at),
      select: %{
        date: fragment("DATE(?)", m.inserted_at),
        message_count: count(m.id)
      },
      order_by: fragment("DATE(?)", m.inserted_at)
    ) |> Repo.all()

    # Hourly distribution (what hours are most active)
    hourly_distribution = from(m in Message,
      join: s in Session, on: s.id == m.session_id,
      where: s.tenant_id == ^tenant_id and m.inserted_at >= ^start_datetime,
      group_by: fragment("EXTRACT(hour FROM ?)", m.inserted_at),
      select: %{
        hour: fragment("EXTRACT(hour FROM ?)", m.inserted_at),
        message_count: count(m.id)
      },
      order_by: fragment("EXTRACT(hour FROM ?)", m.inserted_at)
    ) |> Repo.all()

    # Most active users
    top_users = from(m in Message,
      join: s in Session, on: s.id == m.session_id,
      join: u in Accounts.User, on: u.id == m.user_id,
      where: s.tenant_id == ^tenant_id and m.inserted_at >= ^start_datetime and m.role == :user,
      group_by: [m.user_id, u.username, u.first_name, u.last_name],
      select: %{
        user_id: m.user_id,
        username: u.username,
        name: fragment("COALESCE(?, ?)", u.first_name, u.username),
        message_count: count(m.id)
      },
      order_by: [desc: count(m.id)],
      limit: 10
    ) |> Repo.all()

    %{
      daily_messages: daily_messages,
      hourly_distribution: hourly_distribution,
      top_users: top_users
    }
  end

  @doc """
  Gets model performance and usage statistics.
  """
  def get_model_stats(tenant_id, start_date \\ nil) do
    start_date = start_date || Date.utc_today() |> Date.add(-30)
    start_datetime = DateTime.new!(start_date, ~T[00:00:00], "Etc/UTC")

    model_performance = from(u in UsageRecord,
      where: u.tenant_id == ^tenant_id and u.inserted_at >= ^start_datetime,
      group_by: u.model,
      select: %{
        model: u.model,
        avg_response_time: avg(u.request_duration_ms),
        success_rate: fragment("ROUND(AVG(CASE WHEN ? THEN 100.0 ELSE 0.0 END), 1)", u.success),
        total_requests: count(u.id),
        avg_tokens_per_request: avg(u.total_tokens),
        total_cost_cents: sum(u.total_cost_cents)
      },
      order_by: [desc: count(u.id)]
    ) |> Repo.all()

    %{
      performance: Enum.map(model_performance, &format_model_performance/1)
    }
  end

  @doc """
  Gets user engagement statistics.
  """
  def get_user_stats(tenant_id, start_date \\ nil) do
    start_date = start_date || Date.utc_today() |> Date.add(-30)
    start_datetime = DateTime.new!(start_date, ~T[00:00:00], "Etc/UTC")

    # Total active users
    active_users = from(m in Message,
      join: s in Session, on: s.id == m.session_id,
      where: s.tenant_id == ^tenant_id and m.inserted_at >= ^start_datetime and m.role == :user,
      distinct: m.user_id
    ) |> Repo.aggregate(:count)

    # User engagement levels
    user_engagement = from(m in Message,
      join: s in Session, on: s.id == m.session_id,
      join: u in Accounts.User, on: u.id == m.user_id,
      where: s.tenant_id == ^tenant_id and m.inserted_at >= ^start_datetime and m.role == :user,
      group_by: [m.user_id, u.username],
      select: %{
        user_id: m.user_id,
        username: u.username,
        message_count: count(m.id),
        session_count: count(s.id, :distinct),
        last_activity: max(m.inserted_at)
      },
      order_by: [desc: count(m.id)]
    ) |> Repo.all()

    %{
      active_users: active_users,
      engagement: user_engagement
    }
  end

  @doc """
  Gets trend data showing changes over time.
  """
  def get_trend_data(tenant_id, start_date \\ nil) do
    start_date = start_date || Date.utc_today() |> Date.add(-30)
    start_datetime = DateTime.new!(start_date, ~T[00:00:00], "Etc/UTC")

    # Weekly trends
    weekly_trends = from(u in UsageRecord,
      where: u.tenant_id == ^tenant_id and u.inserted_at >= ^start_datetime,
      group_by: fragment("DATE_TRUNC('week', ?)", u.inserted_at),
      select: %{
        week: fragment("DATE_TRUNC('week', ?)", u.inserted_at),
        total_requests: count(u.id),
        total_tokens: sum(u.total_tokens),
        total_cost_cents: sum(u.total_cost_cents),
        avg_response_time: avg(u.request_duration_ms)
      },
      order_by: fragment("DATE_TRUNC('week', ?)", u.inserted_at)
    ) |> Repo.all()

    %{
      weekly: weekly_trends
    }
  end

  # Private helper functions

  defp calculate_success_rate(successful, total) when total > 0 do
    Float.round(successful / total * 100, 1)
  end
  defp calculate_success_rate(_, _), do: 0.0

  defp format_usage_stat(stat) do
    %{
      provider: stat.provider,
      total_tokens: stat.total_tokens || 0,
      total_cost: (stat.total_cost_cents || 0) / 100.0,
      request_count: stat.request_count || 0
    }
  end

  defp format_model_stat(stat) do
    %{
      model: stat.model,
      total_tokens: stat.total_tokens || 0,
      total_cost: (stat.total_cost_cents || 0) / 100.0,
      request_count: stat.request_count || 0,
      avg_duration_ms: safe_round_float(stat.avg_duration_ms, 1)
    }
  end

  defp format_model_performance(perf) do
    %{
      model: perf.model,
      avg_response_time: safe_round_float(perf.avg_response_time, 1),
      success_rate: safe_round_float(perf.success_rate, 1),
      total_requests: perf.total_requests || 0,
      avg_tokens_per_request: safe_round_float(perf.avg_tokens_per_request, 1),
      total_cost: (perf.total_cost_cents || 0) / 100.0
    }
  end

  # Helper function to safely round floats and decimals
  defp safe_round_float(nil, _precision), do: 0.0
  defp safe_round_float(value, precision) when is_float(value) do
    Float.round(value, precision)
  end
  defp safe_round_float(%Decimal{} = value, precision) do
    value
    |> Decimal.to_float()
    |> Float.round(precision)
  end
  defp safe_round_float(value, precision) when is_number(value) do
    Float.round(value * 1.0, precision)
  end
  defp safe_round_float(_value, _precision), do: 0.0
end
