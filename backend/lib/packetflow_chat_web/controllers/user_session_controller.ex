defmodule PacketflowChatWeb.UserSessionController do
  use PacketflowChatWeb, :controller

  alias PacketflowChat.Accounts

  def create(conn, %{"_action" => "registered"} = params) do
    create(conn, params, "Account created successfully!")
  end

  def create(conn, %{"_action" => "password_updated"} = params) do
    create(conn, params, "Password updated successfully!")
  end

  def create(conn, params) do
    create(conn, params, "Welcome back!")
  end

  defp create(conn, %{"user" => user_params}, info) do
    %{"email" => email, "password" => password} = user_params

    if user = Accounts.get_user_by_email_and_password(email, password) do
      token = Accounts.generate_user_session_token(user)
      encoded_token = Base.encode64(token)

      conn
      |> put_status(:ok)
      |> json(%{
        message: info,
        user: %{
          id: user.id,
          username: user.username,
          email: user.email,
          avatar_url: user.avatar_url
        },
        token: encoded_token
      })
    else
      # In order to prevent user enumeration attacks, don't disclose whether the email is registered.
      conn
      |> put_status(:unauthorized)
      |> json(%{error: "Invalid email or password"})
    end
  end

  def delete(conn, _params) do
    # For API endpoints, the client should handle token removal
    # The token will naturally expire or can be invalidated server-side if needed
    conn
    |> put_status(:ok)
    |> json(%{message: "Logged out successfully"})
  end
end
