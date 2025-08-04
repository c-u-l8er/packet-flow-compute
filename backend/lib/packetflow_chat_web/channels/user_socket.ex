defmodule PacketflowChatWeb.UserSocket do
  use Phoenix.Socket

  alias PacketflowChat.{Auth, Accounts}

  ## Channels
  channel "room:*", PacketflowChatWeb.RoomChannel

  @impl true
  def connect(%{"token" => token}, socket, _connect_info) do
    # First try as base64-encoded session token
    case Base.decode64(token) do
      {:ok, decoded_token} ->
        case Accounts.get_user_by_session_token(decoded_token) do
          %Accounts.User{} = user ->
            {:ok, assign(socket, :user_id, user.id) |> assign(:user, user)}

          nil ->
            # Try as JWT token if session token fails
            try_jwt_auth(token, socket)
        end

      :error ->
        # Not base64, try as JWT token directly
        try_jwt_auth(token, socket)
    end
  end

  defp try_jwt_auth(token, socket) do
    case Auth.verify_token(token) do
      {:ok, clerk_user_id} ->
        case Accounts.get_user_by_clerk_id(clerk_user_id) do
          %Accounts.User{} = user ->
            {:ok, assign(socket, :user_id, user.id) |> assign(:user, user)}

          nil ->
            :error
        end

      {:error, _reason} ->
        :error
    end
  end

  def connect(_params, _socket, _connect_info), do: :error

  @impl true
  def id(socket), do: "user_socket:#{socket.assigns.user_id}"
end
