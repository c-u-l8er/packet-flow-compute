defmodule PacketflowChatDemoWeb.SessionController do
  use PacketflowChatDemoWeb, :controller

  alias PacketflowChatDemo.{Accounts, Guardian}

  def new(conn, _params) do
    render(conn, :new, changeset: Accounts.change_user(%Accounts.User{}))
  end

  def create(conn, %{"user" => %{"email" => email, "password" => password}}) do
    case Accounts.authenticate_user(email, password) do
      {:ok, user} ->
        conn
        |> Guardian.Plug.sign_in(user)
        |> put_flash(:info, "Welcome back!")
        |> redirect(to: ~p"/tenants")

      {:error, _reason} ->
        conn
        |> put_flash(:error, "Invalid email or password.")
        |> render(:new, changeset: Accounts.change_user(%Accounts.User{}))
    end
  end

  def delete(conn, _params) do
    conn
    |> Guardian.Plug.sign_out()
    |> put_flash(:info, "Logged out successfully.")
    |> redirect(to: ~p"/login")
  end
end
