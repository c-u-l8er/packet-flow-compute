defmodule PacketflowChatWeb.UserController do
  use PacketflowChatWeb, :controller

  alias PacketflowChat.Accounts

  action_fallback PacketflowChatWeb.FallbackController

  def me(conn, _params) do
    user_id = conn.assigns.current_user_id

    case Accounts.get_user_by_clerk_id(user_id) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "User not found"})

      user ->
        json(conn, %{
          id: user.id,
          clerk_user_id: user.clerk_user_id,
          username: user.username,
          email: user.email,
          avatar_url: user.avatar_url
        })
    end
  end

  def create_or_update(conn, user_params) do
    case Accounts.create_or_update_user(user_params) do
      {:ok, user} ->
        conn
        |> put_status(:created)
        |> json(%{
          id: user.id,
          clerk_user_id: user.clerk_user_id,
          username: user.username,
          email: user.email,
          avatar_url: user.avatar_url
        })

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: format_errors(changeset)})
    end
  end

  def update(conn, user_params) do
    user_id = conn.assigns.current_user_id

    case Accounts.get_user_by_clerk_id(user_id) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "User not found"})

      user ->
        case Accounts.update_user(user, user_params) do
          {:ok, updated_user} ->
            json(conn, %{
              id: updated_user.id,
              clerk_user_id: updated_user.clerk_user_id,
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

  defp format_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end