defmodule PacketflowChatWeb.CorsController do
  use PacketflowChatWeb, :controller

  def options(conn, _params) do
    send_resp(conn, 200, "")
  end
end
