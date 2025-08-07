defmodule PacketflowChatWeb.UserController do
  use PacketflowChatWeb, :controller

  alias PacketflowChat.Accounts

  action_fallback PacketflowChatWeb.FallbackController

  def me(conn, _params) do
    case conn.assigns[:current_user] do
      nil ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "User not authenticated"})

      user ->
        json(conn, %{
          user: %{
            id: user.id,
            username: user.username,
            email: user.email,
            avatar_url: user.avatar_url
          }
        })
    end
  end

  def session_token(conn, _params) do
    # This endpoint should not be used with the new token-based auth
    # The token is returned directly from login/registration endpoints
    conn
    |> put_status(:gone)
    |> json(%{error: "This endpoint is deprecated. Use login or registration endpoints to get tokens."})
  end

  def create_or_update(conn, user_params) do
    # This endpoint is deprecated as it was used for Clerk integration
    conn
    |> put_status(:gone)
    |> json(%{error: "This endpoint is deprecated. Use registration endpoint instead."})
  end

  def update(conn, user_params) do
    case conn.assigns[:current_user] do
      nil ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "User not authenticated"})

      user ->
        case Accounts.update_user(user, user_params) do
          {:ok, updated_user} ->
            json(conn, %{
              id: updated_user.id,
              username: updated_user.username,
              email: updated_user.email,
              avatar_url: updated_user.avatar_url
            })

          {:error, changeset} ->
            conn
            |> put_status(:unprocessable_entity)
            |> json(%{errors: format_errors(changeset)})
        end
    end
  end

  def search(conn, %{"q" => query}) do
    case conn.assigns[:current_user] do
      nil ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "User not authenticated"})

      _user ->
        users = Accounts.search_users(query, 10)
        json(conn, %{users: users})
    end
  end

  def search(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "Query parameter 'q' is required"})
  end

  defp format_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
