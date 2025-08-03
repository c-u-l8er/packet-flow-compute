defmodule PacketflowChatWeb.Router do
  use PacketflowChatWeb, :router

  def authenticate_request(conn, opts) do
    PacketflowChat.Auth.authenticate_request(conn, opts)
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug CORSPlug
  end

  pipeline :authenticated_api do
    plug :accepts, ["json"]
    plug CORSPlug
    plug :authenticate_request
  end

  scope "/api", PacketflowChatWeb do
    pipe_through :api

    # Public routes
    post "/users", UserController, :create_or_update
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

  # Catch-all route for frontend SPA - must be last
  scope "/", PacketflowChatWeb do
    pipe_through :api
    
    get "/*path", PageController, :index
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
end
