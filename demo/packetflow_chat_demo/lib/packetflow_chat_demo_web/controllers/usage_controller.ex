defmodule PacketflowChatDemoWeb.UsageController do
  use PacketflowChatDemoWeb, :controller

  alias PacketflowChatDemo.{Accounts, Usage}

  plug :require_auth

  def dashboard(conn, %{"tenant_slug" => tenant_slug}) do
    tenant = Accounts.get_tenant_by_slug!(tenant_slug)

    # Verify user is owner or admin
    unless Accounts.tenant_owner?(tenant.id, conn.assigns.current_user.id) do
      conn
      |> put_flash(:error, "Only tenant owners can access usage dashboard.")
      |> redirect(to: ~p"/#{tenant_slug}/chat")
      |> halt()
    end

    # Get usage statistics
    stats = Usage.get_tenant_stats(tenant.id)

    # Get monthly summaries for the last 12 months
    monthly_summaries = Usage.get_tenant_monthly_summaries(tenant.id)
    |> Enum.take(12)

    # Get current month details
    current_date = Date.utc_today()
    start_of_month = Date.beginning_of_month(current_date)
    end_of_month = Date.end_of_month(current_date)

    current_month_usage = Usage.get_tenant_usage(
      tenant.id,
      DateTime.new!(start_of_month, ~T[00:00:00]),
      DateTime.new!(end_of_month, ~T[23:59:59])
    )
    |> Enum.take(100)  # Limit to recent 100 records

    render(conn, :dashboard,
      tenant: tenant,
      stats: stats,
      monthly_summaries: monthly_summaries,
      current_month_usage: current_month_usage,
      current_date: current_date
    )
  end

  def export_csv(conn, %{"tenant_slug" => tenant_slug} = params) do
    tenant = Accounts.get_tenant_by_slug!(tenant_slug)

    # Verify user is owner or admin
    unless Accounts.tenant_owner?(tenant.id, conn.assigns.current_user.id) do
      conn
      |> put_flash(:error, "Only tenant owners can export usage data.")
      |> redirect(to: ~p"/#{tenant_slug}/usage")
      |> halt()
    end

    # Parse date range
    start_date = case params["start_date"] do
      nil -> Date.add(Date.utc_today(), -30)
      date_str -> Date.from_iso8601!(date_str)
    end

    end_date = case params["end_date"] do
      nil -> Date.utc_today()
      date_str -> Date.from_iso8601!(date_str)
    end

    # Get usage records
    usage_records = Usage.get_tenant_usage(
      tenant.id,
      DateTime.new!(start_date, ~T[00:00:00]),
      DateTime.new!(end_date, ~T[23:59:59])
    )

    # Generate CSV
    csv_content = generate_csv(usage_records)

    filename = "usage_#{tenant.slug}_#{start_date}_to_#{end_date}.csv"

    conn
    |> put_resp_content_type("text/csv")
    |> put_resp_header("content-disposition", "attachment; filename=\"#{filename}\"")
    |> send_resp(200, csv_content)
  end

  defp require_auth(conn, _opts) do
    if conn.assigns[:current_user] do
      conn
    else
      conn
      |> put_flash(:error, "You must be logged in to access this page.")
      |> redirect(to: ~p"/login")
      |> halt()
    end
  end

  defp generate_csv(usage_records) do
    headers = [
      "Date",
      "User ID",
      "Session ID",
      "Model",
      "Provider",
      "Prompt Tokens",
      "Completion Tokens",
      "Total Tokens",
      "Cost (USD)",
      "Success"
    ]

    rows = Enum.map(usage_records, fn record ->
      [
        DateTime.to_date(record.inserted_at) |> Date.to_string(),
        record.user_id,
        record.session_id,
        record.model,
        record.provider,
        record.prompt_tokens,
        record.completion_tokens,
        record.total_tokens,
        record.total_cost_cents / 100.0,
        record.success
      ]
    end)

    [headers | rows]
    |> Enum.map(&Enum.join(&1, ","))
    |> Enum.join("\n")
  end
end
