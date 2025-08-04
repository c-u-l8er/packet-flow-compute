defmodule PacketflowChatWeb.UserRegistrationController do
  use PacketflowChatWeb, :controller

  alias PacketflowChat.Accounts

  def create(conn, %{"user" => user_params}) do
    case Accounts.register_user(user_params) do
      {:ok, user} ->
        {:ok, _} =
          Accounts.deliver_user_confirmation_instructions(
            user,
            &url(~p"/users/confirm/#{&1}")
          )

        token = Accounts.generate_user_session_token(user)
        encoded_token = Base.encode64(token)

        conn
        |> put_status(:created)
        |> json(%{
          message: "User created successfully",
          user: %{
            id: user.id,
            username: user.username,
            email: user.email,
            avatar_url: user.avatar_url
          },
          token: encoded_token
        })

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{
          error: "Registration failed",
          errors: format_changeset_errors(changeset)
        })
    end
  end

  defp format_changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
