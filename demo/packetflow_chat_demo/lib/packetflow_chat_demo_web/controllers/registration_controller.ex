defmodule PacketflowChatDemoWeb.RegistrationController do
  use PacketflowChatDemoWeb, :controller

  alias PacketflowChatDemo.{Accounts, Guardian}

  def new(conn, _params) do
    changeset = Accounts.change_user(%Accounts.User{})
    render(conn, :new, changeset: changeset)
  end

  def create(conn, %{"user" => user_params}) do
    case Accounts.create_user(user_params) do
      {:ok, user} ->
        conn
        |> Guardian.Plug.sign_in(user)
        |> put_flash(:info, "Account created successfully!")
        |> redirect(to: ~p"/tenants")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :new, changeset: changeset)
    end
  end
end
