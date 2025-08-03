defmodule PacketflowChatWeb.PageController do
  use PacketflowChatWeb, :controller

  def index(conn, _params) do
    # For SPA, we want to serve a simple response that indicates the backend is running
    # In a real setup, you might serve the frontend build files here
    json(conn, %{
      message: "PacketFlow Chat Backend is running",
      status: "ok",
      frontend_url: "http://localhost:5173"
    })
  end
end