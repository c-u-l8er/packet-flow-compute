defmodule PacketflowChatWeb.Router do
  use PacketflowChatWeb, :router

  def authenticate_request(conn, opts) do
    PacketflowChat.Auth.authenticate_request(conn, opts)
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug CORSPlug, origin: ["http://localhost:5173", "http://localhost:3000"]
  end

  pipeline :authenticated_api do
    plug :accepts, ["json"]
    plug CORSPlug, origin: ["http://localhost:5173", "http://localhost:3000"]
    plug :authenticate_request
  end

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug PacketflowChat.Auth, :fetch_current_user
  end

  scope "/api", PacketflowChatWeb do
    pipe_through :api

    # OPTIONS routes for CORS preflight requests - ALL routes (public and authenticated)
    options "/users", CorsController, :options
    options "/users/register", CorsController, :options
    options "/users/log_in", CorsController, :options
    options "/users/log_out", CorsController, :options
    options "/users/confirm", CorsController, :options
    options "/users/session_token", CorsController, :options
    options "/users/me", CorsController, :options
    options "/users/search", CorsController, :options
    options "/rooms", CorsController, :options
    options "/rooms/public", CorsController, :options
    options "/rooms/private", CorsController, :options
    options "/rooms/:id", CorsController, :options
    options "/rooms/:id/join", CorsController, :options
    options "/rooms/:id/leave", CorsController, :options
    options "/rooms/:id/members", CorsController, :options
    options "/rooms/:id/invite", CorsController, :options
    options "/rooms/:id/remove", CorsController, :options
    options "/rooms/:id/role", CorsController, :options

    # AI/PacketFlow CORS options
    options "/ai/plan", CorsController, :options
    options "/ai/execute", CorsController, :options
    options "/ai/capability/:capability_id", CorsController, :options
    options "/ai/capabilities", CorsController, :options
    options "/ai/analyze-intent", CorsController, :options
    options "/ai/execution/:execution_id", CorsController, :options
    options "/ai/natural", CorsController, :options

    # MCP CORS options
    options "/mcp/request", CorsController, :options
    options "/mcp/tools", CorsController, :options
    options "/mcp/tools/:name/execute", CorsController, :options
    options "/mcp/capabilities", CorsController, :options
    options "/mcp/server-info", CorsController, :options
    options "/mcp/stats", CorsController, :options
    options "/mcp/health", CorsController, :options

    # Public routes
    post "/users", UserController, :create_or_update

    # Authentication routes
    post "/users/register", UserRegistrationController, :create
    post "/users/log_in", UserSessionController, :create
    delete "/users/log_out", UserSessionController, :delete
    post "/users/confirm", UserConfirmationController, :create
    get "/users/confirm/:token", UserConfirmationController, :update
    get "/users/session_token", UserController, :session_token
  end

  scope "/api", PacketflowChatWeb do
    pipe_through :authenticated_api

    # User routes
    get "/users/me", UserController, :me
    put "/users/me", UserController, :update
    get "/users/search", UserController, :search

    # Room routes
    get "/rooms", RoomController, :index
    get "/rooms/public", RoomController, :public_rooms
    get "/rooms/:id", RoomController, :show
    post "/rooms", RoomController, :create
    post "/rooms/private", RoomController, :create_private_with_users
    delete "/rooms/:id", RoomController, :delete
    post "/rooms/:id/join", RoomController, :join
    post "/rooms/:id/leave", RoomController, :leave

    # Room member management routes
    get "/rooms/:id/members", RoomController, :members
    post "/rooms/:id/invite", RoomController, :invite_user
    delete "/rooms/:id/remove", RoomController, :remove_user
    put "/rooms/:id/role", RoomController, :update_user_role

    # AI/PacketFlow routes
    post "/ai/plan", AIController, :generate_plan
    post "/ai/execute", AIController, :execute_plan
    post "/ai/capability/:capability_id", AIController, :execute_capability
    get "/ai/capabilities", AIController, :list_capabilities
    post "/ai/analyze-intent", AIController, :analyze_intent
    get "/ai/execution/:execution_id", AIController, :get_execution_status
    post "/ai/natural", AIController, :natural_language_interface

    # MCP routes
    post "/mcp/request", MCPController, :request
    get "/mcp/tools", MCPController, :list_tools
    post "/mcp/tools/:name/execute", MCPController, :execute_tool
    get "/mcp/capabilities", MCPController, :capabilities
    get "/mcp/server-info", MCPController, :server_info
    get "/mcp/stats", MCPController, :stats
    get "/mcp/health", MCPController, :health
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:packetflow_chat, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through [:fetch_session, :protect_from_forgery]

      live_dashboard "/dashboard", metrics: PacketflowChatWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  # Catch-all route for frontend SPA - must be last
  scope "/", PacketflowChatWeb do
    pipe_through :api

    get "/*path", PageController, :index
  end
end
