defmodule PacketflowChatDemoWeb.TenantController do
  use PacketflowChatDemoWeb, :controller

  alias PacketflowChatDemo.{Accounts, Analytics}
  alias PacketflowChatDemoWeb.Auth

  plug :require_auth

  def index(conn, _params) do
    user_tenants = Accounts.get_user_tenants(conn.assigns.current_user.id)

    # Get analytics for each tenant
    tenants_with_analytics = Enum.map(user_tenants, fn tenant ->
      analytics = Analytics.get_overview_stats(tenant.id, Date.utc_today() |> Date.add(-7))
      Map.put(tenant, :analytics, analytics)
    end)

    render(conn, :index, tenants: tenants_with_analytics)
  end

  def show(conn, %{"id" => id}) do
    tenant = Accounts.get_tenant!(id)

    # Verify user has access
    unless Accounts.tenant_member?(tenant.id, conn.assigns.current_user.id) do
      conn
      |> put_flash(:error, "Access denied.")
      |> redirect(to: ~p"/tenants")
      |> halt()
    end

    # Set the current tenant in session and redirect
    conn
    |> Auth.set_current_tenant(tenant.id)
    |> redirect(to: ~p"/#{tenant.slug}/chat")
  end

  def new(conn, _params) do
    changeset = Accounts.change_tenant(%Accounts.Tenant{})
    render(conn, :new, changeset: changeset)
  end

  def create(conn, %{"tenant" => tenant_params}) do
    # Convert checkbox "on" value to boolean
    processed_params = Map.update(tenant_params, "allow_model_selection", false, fn
      "on" -> true
      value -> value
    end)

    case Accounts.create_tenant(processed_params) do
      {:ok, tenant} ->
        # Make the creator an owner
        {:ok, _member} = Accounts.add_tenant_member(tenant.id, conn.assigns.current_user.id, :owner)

        conn
        |> put_flash(:info, "Tenant created successfully!")
        |> redirect(to: ~p"/tenants/#{tenant.id}")

      {:error, %Ecto.Changeset{} = changeset} ->
        IO.inspect(changeset.errors, label: "Tenant creation errors")
        render(conn, :new, changeset: changeset)
    end
  end

  def settings(conn, %{"tenant_slug" => tenant_slug}) do
    tenant = Accounts.get_tenant_by_slug!(tenant_slug)

    # Verify user is owner
    unless Accounts.tenant_owner?(tenant.id, conn.assigns.current_user.id) do
      conn
      |> put_flash(:error, "Only tenant owners can access settings.")
      |> redirect(to: ~p"/#{tenant_slug}/chat")
      |> halt()
    end

    changeset = Accounts.change_tenant(tenant)
    members = Accounts.get_tenant_members(tenant.id)

    render(conn, :settings,
      tenant: tenant,
      changeset: changeset,
      members: members
    )
  end

  def update_settings(conn, %{"tenant_slug" => tenant_slug, "tenant" => tenant_params}) do
    tenant = Accounts.get_tenant_by_slug!(tenant_slug)

    # Verify user is owner
    unless Accounts.tenant_owner?(tenant.id, conn.assigns.current_user.id) do
      conn
      |> put_flash(:error, "Only tenant owners can update settings.")
      |> redirect(to: ~p"/#{tenant_slug}/chat")
      |> halt()
    end

    case Accounts.update_tenant(tenant, tenant_params) do
      {:ok, _tenant} ->
        conn
        |> put_flash(:info, "Settings updated successfully!")
        |> redirect(to: ~p"/#{tenant_slug}/settings")

      {:error, %Ecto.Changeset{} = changeset} ->
        members = Accounts.get_tenant_members(tenant.id)
        render(conn, :settings,
          tenant: tenant,
          changeset: changeset,
          members: members
        )
    end
  end

  def edit(conn, %{"id" => id}) do
    tenant = Accounts.get_tenant!(id)

    # Verify user is owner
    unless Accounts.tenant_owner?(tenant.id, conn.assigns.current_user.id) do
      conn
      |> put_flash(:error, "Only tenant owners can edit organizations.")
      |> redirect(to: ~p"/tenants")
      |> halt()
    end

    changeset = Accounts.change_tenant(tenant)
    render(conn, :edit, tenant: tenant, changeset: changeset)
  end

  def update(conn, %{"id" => id, "tenant" => tenant_params}) do
    tenant = Accounts.get_tenant!(id)

    # Verify user is owner
    unless Accounts.tenant_owner?(tenant.id, conn.assigns.current_user.id) do
      conn
      |> put_flash(:error, "Only tenant owners can update organizations.")
      |> redirect(to: ~p"/tenants")
      |> halt()
    end

    # Convert checkbox "on" value to boolean
    processed_params = Map.update(tenant_params, "allow_model_selection", false, fn
      "on" -> true
      value -> value
    end)

    case Accounts.update_tenant(tenant, processed_params) do
      {:ok, _updated_tenant} ->
        conn
        |> put_flash(:info, "Organization updated successfully!")
        |> redirect(to: ~p"/tenants")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :edit, tenant: tenant, changeset: changeset)
    end
  end

  def delete(conn, %{"id" => id}) do
    tenant = Accounts.get_tenant!(id)

    # Verify user is owner
    unless Accounts.tenant_owner?(tenant.id, conn.assigns.current_user.id) do
      conn
      |> put_flash(:error, "Only tenant owners can delete organizations.")
      |> redirect(to: ~p"/tenants")
      |> halt()
    end

    case Accounts.delete_tenant(tenant) do
      {:ok, _tenant} ->
        conn
        |> put_flash(:info, "Organization deleted successfully!")
        |> redirect(to: ~p"/tenants")

      {:error, _changeset} ->
        conn
        |> put_flash(:error, "Failed to delete organization.")
        |> redirect(to: ~p"/tenants")
    end
  end

  def analytics(conn, %{"tenant_slug" => tenant_slug} = params) do
    tenant = Accounts.get_tenant_by_slug!(tenant_slug)

    # Verify user has access
    unless Accounts.tenant_member?(tenant.id, conn.assigns.current_user.id) do
      conn
      |> put_flash(:error, "Access denied.")
      |> redirect(to: ~p"/tenants")
      |> halt()
    end

    days = String.to_integer(params["days"] || "30")
    analytics = Analytics.get_tenant_analytics(tenant.id, days: days)

    render(conn, :analytics,
      tenant: tenant,
      analytics: analytics,
      days: days
    )
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
end
