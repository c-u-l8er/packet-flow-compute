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
    options "/rooms", CorsController, :options
    options "/rooms/public", CorsController, :options
    options "/rooms/:id", CorsController, :options
    options "/rooms/:id/join", CorsController, :options
    options "/rooms/:id/leave", CorsController, :options

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

    # Room routes
    get "/rooms", RoomController, :index
    get "/rooms/public", RoomController, :public_rooms
    get "/rooms/:id", RoomController, :show
    post "/rooms", RoomController, :create
    post "/rooms/:id/join", RoomController, :join
    post "/rooms/:id/leave", RoomController, :leave
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
