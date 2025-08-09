defmodule PacketflowChatDemoWeb.PageController do
  use PacketflowChatDemoWeb, :controller

  def home(conn, _params) do
    if conn.assigns[:current_user] do
      redirect(conn, to: ~p"/tenants")
    else
      render(conn, :home)
    end
  end
end
