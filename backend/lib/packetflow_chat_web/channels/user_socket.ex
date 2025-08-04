defmodule PacketflowChatWeb.UserSocket do
  use Phoenix.Socket

  alias PacketflowChat.Accounts

  ## Channels
  channel "room:*", PacketflowChatWeb.RoomChannel

  @impl true
  def connect(%{"token" => token}, socket, _connect_info) do
    # Decode base64-encoded session token
    case Base.decode64(token) do
      {:ok, decoded_token} ->
        case Accounts.get_user_by_session_token(decoded_token) do
          %Accounts.User{} = user ->
            {:ok, assign(socket, :user_id, user.id) |> assign(:user, user)}

          nil ->
            :error
        end

      :error ->
        :error
    end
  end

  def connect(_params, _socket, _connect_info), do: :error

  @impl true
  def id(socket), do: "user_socket:#{socket.assigns.user_id}"
end
