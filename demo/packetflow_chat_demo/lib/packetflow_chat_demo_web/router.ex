defmodule PacketflowChatDemoWeb.Router do
  use PacketflowChatDemoWeb, :router

    # Plug to put current user in session for LiveView
  def put_current_user_in_session(conn, _opts) do
    case Guardian.Plug.current_resource(conn) do
      nil -> conn
      user ->
        conn
        |> put_session(:current_user_id, user.id)
        |> put_session(:guardian_token, Guardian.Plug.current_token(conn))
    end
  end

  # Session function for LiveView - extracts session data for WebSocket
  def put_guardian_session(conn) do
    %{
      "current_user_id" => get_session(conn, :current_user_id),
      "guardian_token" => get_session(conn, :guardian_token),
      "guardian_default_token" => Guardian.Plug.current_token(conn)
    }
    |> Enum.filter(fn {_k, v} -> v != nil end)
    |> Enum.into(%{})
  end

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {PacketflowChatDemoWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug Guardian.Plug.Pipeline, module: PacketflowChatDemo.Guardian,
                                  error_handler: PacketflowChatDemoWeb.AuthErrorHandler
    plug Guardian.Plug.VerifySession, claims: %{"typ" => "access"}
    plug Guardian.Plug.LoadResource, allow_blank: true
    plug PacketflowChatDemoWeb.Auth
  end

  pipeline :require_auth do
    plug Guardian.Plug.EnsureAuthenticated
  end

  pipeline :put_user_in_session do
    plug :put_current_user_in_session
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", PacketflowChatDemoWeb do
    pipe_through :browser

    # Public routes
    get "/", PageController, :home
    get "/login", SessionController, :new
    post "/login", SessionController, :create
    get "/register", RegistrationController, :new
    post "/register", RegistrationController, :create
    get "/logout", SessionController, :delete
    delete "/logout", SessionController, :delete
  end

  scope "/", PacketflowChatDemoWeb do
    pipe_through [:browser, :require_auth]

    # Tenant management
    resources "/tenants", TenantController do
      get "/settings", TenantController, :settings, as: :tenant_settings
      put "/settings", TenantController, :update_settings, as: :tenant_settings
    end
  end

  scope "/:tenant_slug", PacketflowChatDemoWeb do
    pipe_through [:browser, :require_auth, :put_user_in_session]

    # Tenant-scoped routes
    live_session :authenticated,
      on_mount: {PacketflowChatDemoWeb.LiveAuth, :ensure_authenticated},
      session: {__MODULE__, :put_guardian_session, []} do
      live "/chat", EnterpriseChatLive, :index
    end
    get "/settings", TenantController, :settings
    put "/settings", TenantController, :update_settings
    get "/analytics", TenantController, :analytics
    get "/usage", UsageController, :dashboard
    get "/usage/export", UsageController, :export_csv
  end

  # Other scopes may use custom stacks.
  # scope "/api", PacketflowChatDemoWeb do
  #   pipe_through :api
  # end



  # Enable LiveDashboard in development
  if Application.compile_env(:packetflow_chat_demo, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: PacketflowChatDemoWeb.Telemetry
    end
  end
end
