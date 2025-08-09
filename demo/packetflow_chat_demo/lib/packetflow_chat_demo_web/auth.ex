defmodule PacketflowChatDemoWeb.Auth do
  @moduledoc """
  Authentication helpers and plugs.
  """

  import Plug.Conn
  import Phoenix.Controller

  use Phoenix.VerifiedRoutes,
    endpoint: PacketflowChatDemoWeb.Endpoint,
    router: PacketflowChatDemoWeb.Router,
    statics: PacketflowChatDemoWeb.static_paths()

  alias PacketflowChatDemo.{Accounts, Guardian}

  def init(opts), do: opts

  def call(conn, _opts) do
    current_user = Guardian.Plug.current_resource(conn)
    current_tenant = get_current_tenant(conn, current_user)

    conn
    |> assign(:current_user, current_user)
    |> assign(:current_tenant, current_tenant)
    |> assign(:user_tenants, get_user_tenants(current_user))
  end

  def require_auth(conn, _opts) do
    if conn.assigns[:current_user] do
      conn
    else
      conn
      |> put_flash(:error, "You must be logged in to access this page.")
      |> redirect(to: ~p"/login")
      |> halt()
    end
  end

  def require_tenant(conn, _opts) do
    case conn.assigns[:current_tenant] do
      nil ->
        conn
        |> put_flash(:error, "Please select a tenant.")
        |> redirect(to: ~p"/tenants")
        |> halt()

      tenant ->
        # Verify user has access to this tenant
        if Accounts.tenant_member?(tenant.id, conn.assigns.current_user.id) do
          conn
        else
          conn
          |> put_flash(:error, "Access denied.")
          |> redirect(to: ~p"/tenants")
          |> halt()
        end
    end
  end

  def require_tenant_owner(conn, _opts) do
    case conn.assigns[:current_tenant] do
      nil ->
        conn
        |> put_flash(:error, "Please select a tenant.")
        |> redirect(to: ~p"/tenants")
        |> halt()

      tenant ->
        if Accounts.tenant_owner?(tenant.id, conn.assigns.current_user.id) do
          conn
        else
          conn
          |> put_flash(:error, "Only tenant owners can access this page.")
          |> redirect(to: ~p"/")
          |> halt()
        end
    end
  end

  defp get_current_tenant(conn, user) do
    cond do
      # Check if tenant is specified in path params
      tenant_slug = conn.params["tenant_slug"] ->
        case Accounts.get_tenant_by_slug(tenant_slug) do
          nil -> nil
          tenant ->
            if user && Accounts.tenant_member?(tenant.id, user.id) do
              tenant
            else
              nil
            end
        end

      # Check session for selected tenant
      tenant_id = get_session(conn, :current_tenant_id) ->
        case Accounts.get_tenant(tenant_id) do
          nil -> nil
          tenant ->
            if user && Accounts.tenant_member?(tenant.id, user.id) do
              tenant
            else
              nil
            end
        end

      # Default to user's first tenant
      user ->
        case Accounts.get_user_tenants(user.id) do
          [tenant | _] -> tenant
          [] -> nil
        end

      true ->
        nil
    end
  end

  defp get_user_tenants(nil), do: []
  defp get_user_tenants(user), do: Accounts.get_user_tenants(user.id)

  def set_current_tenant(conn, tenant_id) do
    put_session(conn, :current_tenant_id, tenant_id)
  end
end
